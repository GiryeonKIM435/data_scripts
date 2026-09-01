function [idxContact, info] = detectForceRiseOnset(defLoad, forceLoad, sigmaNoiseN, cfg)
%DETECTFORCERISEONSET 正傾きアンカーから 2σ 以下変化の連続区間を逆遡り接触点を検出

if nargin < 4 || isempty(cfg)
    cfg = KrContactConfig();
end

defLoad = defLoad(:);
forceLoad = forceLoad(:);
n = numel(forceLoad);
info = struct();
info.method = cfg.method;
info.sigmaNoiseN = sigmaNoiseN;
info.detected = false;
info.obviousRunStart = nan;
info.obviousRunEnd = nan;
info.slackRunStart = nan;
info.slackRunEnd = nan;

if n < 1
    idxContact = 1;
    return;
end

dFThr = computeSlackDeltaThreshold(sigmaNoiseN, cfg);
info.slackDeltaThrN = dFThr;
info.minSlackRun = cfg.minSlackRun;

if n < 2
    idxContact = 1;
    fillStartInfo(info, defLoad, forceLoad, idxContact);
    info.fallback = "short_series";
    return;
end

slope = computeLocalSlope(defLoad, forceLoad, cfg.minDefStepMm);
[slopeThrObvious, slopeThrPositive] = computeSlopeThresholds(slope, n, cfg);
info.slopeThrObvious = slopeThrObvious;
info.slopeThrPositive = slopeThrPositive;

minRun = cfg.minObviousRun;
[runStart, runEnd, foundObvious] = findFirstObviousSlopeRun( ...
    slope, slopeThrObvious, minRun);

if foundObvious
    J = runStart;
    info.obviousRunStart = runStart;
    info.obviousRunEnd = runEnd;
    [idxContact, slackStart, slackEnd, foundSlack] = backtrackSlackContact( ...
        forceLoad, J, dFThr, cfg.minSlackRun);
    info.slackRunStart = slackStart;
    info.slackRunEnd = slackEnd;
    info.detected = foundSlack;
    if ~foundSlack
        info.fallback = "obviousNoSlackRun";
    end
    fillStartInfo(info, defLoad, forceLoad, idxContact);
    return;
end

posMask = isfinite(slope) & slope > slopeThrPositive;
posIdx = find(posMask);
if ~isempty(posIdx)
    J = posIdx(end);
    [idxContact, slackStart, slackEnd, foundSlack] = backtrackSlackContact( ...
        forceLoad, J, dFThr, cfg.minSlackRun);
    info.slackRunStart = slackStart;
    info.slackRunEnd = slackEnd;
    info.detected = false;
    if foundSlack
        info.fallback = "positiveSlopeSlack";
    else
        info.fallback = "positiveSlopeNoSlack";
    end
    fillStartInfo(info, defLoad, forceLoad, idxContact);
    return;
end

[~, maxIdx] = max(slope, [], "omitnan");
if isfinite(maxIdx) && maxIdx >= 1
    J = maxIdx;
    [idxContact, slackStart, slackEnd, foundSlack] = backtrackSlackContact( ...
        forceLoad, J, dFThr, cfg.minSlackRun);
    info.slackRunStart = slackStart;
    info.slackRunEnd = slackEnd;
    info.detected = false;
    if foundSlack
        info.fallback = "maxSlopeSlack";
    else
        info.fallback = "maxSlopeNoSlack";
    end
    fillStartInfo(info, defLoad, forceLoad, idxContact);
    return;
end

idxContact = 1;
info.detected = false;
info.fallback = "index1";
fillStartInfo(info, defLoad, forceLoad, idxContact);

end

function dFThr = computeSlackDeltaThreshold(sigmaNoiseN, cfg)
dFThr = 0;
if isfinite(sigmaNoiseN) && sigmaNoiseN > 0
    mult = cfg.slackSigmaMult;
    if ~isfield(cfg, "slackSigmaMult") || isempty(cfg.slackSigmaMult)
        mult = 2;
    end
    dFThr = mult * sigmaNoiseN;
end
end

function [slopeThrObvious, slopeThrPositive] = computeSlopeThresholds(slope, n, cfg)
nBase = max(cfg.baselineMinPoints, floor(cfg.baselineFrac * n));
nBase = min(nBase, n);
slopeBase = slope(1:nBase);
slopeBase = slopeBase(isfinite(slopeBase));
if isempty(slopeBase)
    slopeThrObvious = 0;
    slopeThrPositive = 0;
    return;
end
medSlope = median(slopeBase, "omitnan");
stdSlope = std(slopeBase, "omitnan");
if ~isfinite(stdSlope) || stdSlope <= eps
    stdSlope = 0;
end
slopeThrObvious = max(0, medSlope + cfg.obviousSigmaMult * stdSlope);
posMult = cfg.positiveSigmaMult;
if ~isfield(cfg, "positiveSigmaMult") || isempty(cfg.positiveSigmaMult)
    posMult = 4;
end
slopeThrPositive = max(0, medSlope + posMult * stdSlope);
end

function [runStart, runEnd, found] = findFirstObviousSlopeRun( ...
    slope, slopeThrObvious, minRun)
runStart = nan;
runEnd = nan;
found = false;
n = numel(slope);
if n < minRun
    return;
end

i = 1;
while i <= n - minRun + 1
    if ~isObviousSlopePoint(slope(i), slopeThrObvious)
        i = i + 1;
        continue;
    end
    j = i;
    while j <= n && isObviousSlopePoint(slope(j), slopeThrObvious)
        j = j + 1;
    end
    runEndCandidate = j - 1;
    runLen = runEndCandidate - i + 1;
    if runLen >= minRun
        runStart = i;
        runEnd = runEndCandidate;
        found = true;
        return;
    end
    i = runEndCandidate + 1;
end

end

function ok = isObviousSlopePoint(s, slopeThrObvious)
ok = isfinite(s) && s > 0 && s > slopeThrObvious;
end

function info = fillStartInfo(info, defLoad, forceLoad, idxContact)
info.startForceN = forceLoad(idxContact);
info.startDefMm = defLoad(idxContact);
end

function [idxContact, slackStart, slackEnd, found] = backtrackSlackContact( ...
    forceLoad, J, dFThr, minRun)
n = numel(forceLoad);
idxContact = max(1, min(J, n));
slackStart = nan;
slackEnd = nan;
found = false;

if n < 2 || minRun < 1
    return;
end

quiet = false(n, 1);
for i = 2:n
    quiet(i) = abs(forceLoad(i) - forceLoad(i - 1)) <= dFThr;
end
if n >= 2
    quiet(1) = quiet(2);
end

searchTo = min(J, n);
for endIdx = searchTo:-1:minRun
    startIdx = endIdx - minRun + 1;
    if startIdx < 1
        continue;
    end
    if all(quiet(startIdx:endIdx))
        slackStart = startIdx;
        slackEnd = endIdx;
        found = true;
        idxContact = min(endIdx + 1, n);
        return;
    end
end

end

function slope = computeLocalSlope(defLoad, forceLoad, minDefStepMm)
n = numel(defLoad);
slope = nan(n, 1);
if n < 2
    return;
end

for i = 1:n
    if i == 1
        dDef = defLoad(2) - defLoad(1);
        dForce = forceLoad(2) - forceLoad(1);
    elseif i == n
        dDef = defLoad(n) - defLoad(n - 1);
        dForce = forceLoad(n) - forceLoad(n - 1);
    else
        dDef = defLoad(i + 1) - defLoad(i - 1);
        dForce = forceLoad(i + 1) - forceLoad(i - 1);
    end
    if abs(dDef) >= minDefStepMm
        slope(i) = dForce / dDef;
    end
end

end
