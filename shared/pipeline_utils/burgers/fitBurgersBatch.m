function [tomatoDataWithFit, fitResults, metadata] = fitBurgersBatch(tomatoData, opts)
%FITBURGERSBATCH Jeffreys creep identification (k2/c1/c2 + creep segment)

if nargin < 2 || isempty(opts)
    opts = burgersDefaultOpts();
end

n = numel(tomatoData);
fitResults = repmat(makeEmptyFitResult(), 1, n);

for i = 1:n
    fitResults(i) = fitBurgersOneId(tomatoData(i), opts);
end

[fitResults, outlierInfo] = rejectOutlierFitsByKC(fitResults, opts);

tomatoDataWithFit = appendSlimBurgersFit(tomatoData, fitResults);
metadata = struct();
metadata.createdAt = datetime("now");
metadata.nTomato = n;
metadata.nSuccess = nnz([fitResults.success]);
metadata.options = opts;
metadata.outlierRejectInfo = outlierInfo;
fprintf("Jeffreys fit: success=%d / %d\n", metadata.nSuccess, n);
end

function result = fitBurgersOneId(item, opts)
result = makeEmptyFitResult();
result.id = item.id;
% Per-id seed: order-independent, stable across MATLAB sessions.
if isfield(opts, "fitRngSeed") && isfinite(opts.fitRngSeed)
    rng(double(opts.fitRngSeed) + double(item.id), "twister");
end
try
    win = resolveCreepHoldWindow(item, opts);
    tSec = win.tSec;
    defMm = win.defMm;
    creepStartSec = win.creepStartSec;
    creepEndSec = win.creepEndSec;

    loadN = opts.creepLoadGram * 1e-3 * 9.80665;
    [tCreep, yCreep] = extractCreepWindow(tSec, defMm, creepStartSec, creepEndSec, opts.maxPointsForFit, opts.minPoints);
    [kc, fitInfo] = fitBurgersK2C1C2(tCreep, yCreep, loadN, opts);
    metrics = calcReadableMetricsFromKC(kc, loadN, opts.creepHoldDurationSec);

    result.success = true;
    result.message = "ok";
    result.k2_retarded_N_per_mm = kc(1);
    result.c1_viscous_Ns_per_mm = kc(2);
    result.c2_retarded_Ns_per_mm = kc(3);
    result.t50_retardedSec = metrics.t50_retardedSec;
    result.t95_retardedSec = metrics.t95_retardedSec;
    result.creepRateInitial_mm_per_s = metrics.creepRateInitial_mm_per_s;
    result.creepRateLongTerm_mm_per_s = metrics.creepRateLongTerm_mm_per_s;
    result.retardedRatioAtHold = metrics.retardedRatioAtHold;
    result.rmse = fitInfo.rmse;
    result.r2 = fitInfo.r2;
    result.creepSegment = struct("tSecRel", tCreep(:).', "defMm", yCreep(:).', ...
        "yhatMm", fitInfo.yhat(:).');
catch ME
    result.success = false;
    result.message = string(ME.message);
end
end

function r = makeEmptyFitResult()
r = struct("id", nan, "success", false, "message", "", ...
    "k2_retarded_N_per_mm", nan, "c1_viscous_Ns_per_mm", nan, "c2_retarded_Ns_per_mm", nan, ...
    "t50_retardedSec", nan, "t95_retardedSec", nan, ...
    "creepRateInitial_mm_per_s", nan, "creepRateLongTerm_mm_per_s", nan, ...
    "retardedRatioAtHold", nan, "rmse", nan, "r2", nan, ...
    "creepSegment", struct("tSecRel", [], "defMm", []));
end

function [tCreep, yCreep] = extractCreepWindow(tSec, defMm, creepStartSec, creepEndSec, maxN, minN)
startIdx = find(tSec >= creepStartSec, 1, "first");
endIdx = find(tSec <= creepEndSec, 1, "last");
if isempty(startIdx) || isempty(endIdx) || endIdx <= startIdx
    error("creep窓を抽出できません。");
end
tAbs = tSec(startIdx:endIdx);
yAbs = defMm(startIdx:endIdx);
tCreep = tAbs - tAbs(1);
yCreep = yAbs - yAbs(1);
n = numel(tCreep);
if n > maxN
    idx = unique(round(linspace(1, n, maxN)));
    tCreep = tCreep(idx); yCreep = yCreep(idx);
end
if numel(tCreep) < minN, error("creep点数不足"); end
end

function [kc, fitInfo] = fitBurgersK2C1C2(t, y, loadN, opts)
t = t(:) - t(1); y = y(:);
valid = isfinite(t) & isfinite(y);
t = t(valid); y = y(valid);
if numel(t) < 50, error("フィット点数不足"); end
idx10 = max(2, round(0.10 * numel(y)));
idx80 = max(idx10 + 1, round(0.80 * numel(y)));
idx90 = max(idx80 + 1, round(0.90 * numel(y)));
p2Init = max(median(y(idx80:idx90), "omitnan") - median(y(1:idx10), "omitnan"), 1e-6);
dp = diff(y(idx80:end)) ./ diff(t(idx80:end));
dp = dp(isfinite(dp));
p4Init = max(ifelse(isempty(dp), 1e-8, median(dp, "omitnan")), 1e-8);
p3Init = max(t(end) / 5, 1e-3);
q0 = log([max(loadN / p2Init, 1e-6); max(loadN / p4Init, 1e-6); max(loadN / p2Init * p3Init, 1e-6)]);
obj = @(q) sum(robustLoss(y - burgersNoK1(exp(min(max(q,-50),50)), t, loadN), y, opts), "omitnan");
options = optimset("Display", "off", "MaxIter", 4000, "MaxFunEvals", 15000);
bestFval = inf; bestQ = q0;
for iStart = 1:max(1, round(opts.fitNumStarts))
    qInit = ifelse(iStart == 1, q0, q0 + opts.fitInitLogJitterStd * randn(size(q0)));
    [qTmp, fTmp] = fminsearch(obj, qInit, options);
    if isfinite(fTmp) && fTmp < bestFval, bestFval = fTmp; bestQ = qTmp; end
end
if ~isfinite(bestFval), error("k2,c1,c2同定失敗"); end
kc = exp(min(max(bestQ, -50), 50)).';
yhat = burgersNoK1(kc, t, loadN);
fitInfo = struct("rmse", sqrt(mean((y - yhat).^2)), "r2", 1 - sum((y-yhat).^2)/sum((y-mean(y)).^2), "yhat", yhat);
end

function y = burgersNoK1(kc, t, loadN)
k2 = kc(1); c1 = kc(2); c2 = kc(3); tau = c2 / max(k2, eps);
y = loadN / max(k2, eps) * (1 - exp(-t ./ max(tau, eps))) + loadN / max(c1, eps) * t;
end

function rho = robustLoss(res, y, opts)
if ~opts.fitUseRobustLoss, rho = res.^2; return; end
scale = max([1.4826 * mad(y, 1), std(y, "omitnan"), 1e-6]);
u = res / scale; delta = max(opts.fitRobustDelta, 1e-6);
rho = 0.5 * u.^2;
m = abs(u) > delta; rho(m) = delta * (abs(u(m)) - 0.5 * delta);
end

function out = calcReadableMetricsFromKC(kc, loadN, holdSec)
out = struct("t50_retardedSec", nan, "t95_retardedSec", nan, ...
    "creepRateInitial_mm_per_s", nan, "creepRateLongTerm_mm_per_s", nan, "retardedRatioAtHold", nan);
k2 = kc(1); c1 = kc(2); c2 = kc(3);
if ~(all(isfinite([k2,c1,c2])) && k2 > 0 && c1 > 0 && c2 > 0), return; end
tau = c2 / k2; p2 = loadN / k2; p4 = loadN / c1;
out.t50_retardedSec = tau * log(2);
out.t95_retardedSec = tau * log(20);
out.creepRateInitial_mm_per_s = p2 / tau + p4;
out.creepRateLongTerm_mm_per_s = p4;
yHold = burgersNoK1(kc, holdSec, loadN);
retardedPart = p2 * (1 - exp(-holdSec / max(tau, eps)));
if isfinite(yHold) && abs(yHold) > eps
    out.retardedRatioAtHold = retardedPart / yHold;
end
end

function [fitResultsOut, info] = rejectOutlierFitsByKC(fitResultsIn, opts)
fitResultsOut = fitResultsIn;
info = struct("enabled", false, "nRejected", 0, "rejectedIds", []);
if ~opts.rejectParamOutliers, return; end
info.enabled = true;
okIdx = find([fitResultsIn.success]);
if numel(okIdx) < max(4, opts.outlierMinSuccessCount), return; end
P = [[fitResultsIn(okIdx).k2_retarded_N_per_mm].', [fitResultsIn(okIdx).c1_viscous_Ns_per_mm].', [fitResultsIn(okIdx).c2_retarded_Ns_per_mm].'];
isPos = all(isfinite(P) & P > 0, 2);
logP = nan(size(P)); logP(isPos,:) = log10(P(isPos,:));
lowerThr = nan(1,3);
upperThr = nan(1,3);
for j = 1:3
    v = logP(isPos,j); q = quantile(v,[0.25,0.75]);
    iqrV = q(2) - q(1);
    lowerThr(j) = q(1) - opts.outlierIqrMultiplier * iqrV;
    upperThr(j) = q(2) + opts.outlierIqrMultiplier * iqrV;
end
reject = false(numel(okIdx),1);
for i = 1:numel(okIdx)
    if ~isPos(i), reject(i)=true; continue; end
    reject(i) = any(logP(i,:) < lowerThr | logP(i,:) > upperThr);
end
for ii = find(reject).'
    k = okIdx(ii);
    fitResultsOut(k).success = false;
    fitResultsOut(k).message = "excluded: outlier k/c";
    fn = ["k2_retarded_N_per_mm","c1_viscous_Ns_per_mm","c2_retarded_Ns_per_mm", ...
        "t50_retardedSec","t95_retardedSec","creepRateInitial_mm_per_s","creepRateLongTerm_mm_per_s","retardedRatioAtHold","rmse","r2"];
    for f = fn, fitResultsOut(k).(f) = nan; end
end
info.nRejected = nnz(reject);
info.rejectedIds = [fitResultsIn(okIdx(reject)).id];
end

function tomatoOut = appendSlimBurgersFit(tomatoIn, fitResults)
tomatoOut = tomatoIn;
for i = 1:numel(tomatoOut)
    f = fitResults(i);
    tomatoOut(i).burgersFit = struct( ...
        "success", f.success, "message", f.message, ...
        "k2_retarded_N_per_mm", f.k2_retarded_N_per_mm, ...
        "c1_viscous_Ns_per_mm", f.c1_viscous_Ns_per_mm, ...
        "c2_retarded_Ns_per_mm", f.c2_retarded_Ns_per_mm, ...
        "t50_retardedSec", f.t50_retardedSec, ...
        "t95_retardedSec", f.t95_retardedSec, ...
        "creepRateInitial_mm_per_s", f.creepRateInitial_mm_per_s, ...
        "creepRateLongTerm_mm_per_s", f.creepRateLongTerm_mm_per_s, ...
        "retardedRatioAtHold", f.retardedRatioAtHold, ...
        "r2", f.r2, "rmse", f.rmse, ...
        "creepSegment", f.creepSegment);
end
end

function v = ifelse(c,a,b), if c, v=a; else, v=b; end, end
