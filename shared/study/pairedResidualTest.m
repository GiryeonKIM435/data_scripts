function stats = pairedResidualTest(resA, resB, cfg)
%pairedResidualTest ペア LOOCV の ΔMAE 推定 + bootstrap CI/p
%
% 点推定 deltaMae = mean(|e_A|) - mean(|e_B|) = mean(d_i),
%   d_i = |e_A,i| - |e_B,i|（試料ごとの絶対誤差差）
% 主推論: bootstrap 95% CI と bootstrap 両側 p（同一 bootDeltaMae 分布）
% 補助: Wilcoxon 符号順位（d_i の中央値 ≠ 0）

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end

yA = getCvField(resA, "yTrue");
yB = getCvField(resB, "yTrue");
if ~isequal(yA, yB)
    error("pairedResidualTest:Mismatch", "yTrue が一致しません。");
end
y = yA;

predA = getCvField(resA, "yPred");
predB = getCvField(resB, "yPred");
residA = y - predA;
residB = y - predB;

absA = abs(residA);
absB = abs(residB);

try
    pWilcoxon = signrank(absA, absB);
catch
    pWilcoxon = nan;
end

B = cfg.cv.bootstrapSamples;
rng(cfg.cv.bootstrapSeed, "twister");
bootDeltaMae = nan(B, 1);
bootDeltaR2 = nan(B, 1);
bootMaeA = nan(B, 1);
bootMaeB = nan(B, 1);
n = numel(y);
for b = 1:B
    idx = randi(n, n, 1);
    mA = calcMetrics(y(idx), predA(idx));
    mB = calcMetrics(y(idx), predB(idx));
    bootMaeA(b) = mA.mae;
    bootMaeB(b) = mB.mae;
    bootDeltaMae(b) = mA.mae - mB.mae;
    if isfinite(mA.r2) && isfinite(mB.r2)
        bootDeltaR2(b) = mA.r2 - mB.r2;
    end
end

mA = getCvMetrics(resA, y, predA);
mB = getCvMetrics(resB, y, predB);
deltaMae = mA.mae - mB.mae;
perSampleDiff = absA - absB;

stats = struct();
stats.pWilcoxonMae = pWilcoxon;
stats.pBootstrapMae = bootstrapPValue(bootDeltaMae, deltaMae);
stats.deltaMae = deltaMae;
stats.deltaRmse = mA.rmse - mB.rmse;
stats.deltaR2 = mA.r2 - mB.r2;
stats.ciDeltaMae = quantile(bootDeltaMae, [0.025, 0.975]);
stats.ciDeltaR2 = quantile(bootDeltaR2, [0.025, 0.975]);
stats.meanMaeA = mA.mae;
stats.meanMaeB = mB.mae;
stats.ciMeanMaeA = quantile(bootMaeA, [0.025, 0.975]);
stats.ciMeanMaeB = quantile(bootMaeB, [0.025, 0.975]);
stats.pBootstrapMeanComparison = bootstrapPValue(bootDeltaMae, deltaMae);
stats.isMeanCiSeparated = (stats.ciMeanMaeA(1) > stats.ciMeanMaeB(2)) || ...
    (stats.ciMeanMaeB(1) > stats.ciMeanMaeA(2));
stats.perSampleAbsErrorDiff = perSampleDiff;
stats.bootDeltaMae = bootDeltaMae;
stats.bootDeltaR2 = bootDeltaR2;
stats.bootMeanMaeA = bootMaeA;
stats.bootMeanMaeB = bootMaeB;
end

function pVal = bootstrapPValue(bootSamples, ~)
%bootstrapPValue H0: mean ΔMAE = 0 の両側 bootstrap p（CI と整合）
bootSamples = bootSamples(isfinite(bootSamples));
if isempty(bootSamples)
    pVal = nan;
    return;
end
pVal = 2 * min(mean(bootSamples <= 0), mean(bootSamples >= 0));
pVal = min(pVal, 1);
end

function v = getCvField(res, name)
if isfield(res, name)
    v = res.(name);
    return;
end
error("pairedResidualTest:MissingField", "CV 結果に %s がありません。", name);
end

function m = getCvMetrics(res, y, yPred)
if isfield(res, "metrics")
    m = res.metrics;
else
    m = calcMetrics(y, yPred);
end
end
