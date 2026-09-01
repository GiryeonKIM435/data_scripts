function r = fitKrDeformationBand(defC, forceC, yieldInfo, methodDef, fitCfg)
%FITKRDEFORMATIONBAND 変形ベース帯域での kr 推定（カスケード品質付き）

if nargin < 5 || isempty(fitCfg)
    fitCfg = struct();
end
if ~isfield(fitCfg, "krFit") || isempty(fitCfg.krFit)
    fitCfg.krFit = KrFitConfig();
end

defC = defC(yieldInfo.idxContact:end);
forceC = forceC(yieldInfo.idxContact:end);

r = emptyDefKrResult();
switch methodDef.type
    case "percent_def"
        [mask, bandDesc] = buildPercentDefMask(defC, yieldInfo, methodDef);
        r = fitMaskedWithCascade(defC, forceC, mask, fitCfg, bandDesc);
    case "sliding_def"
        r = fitSlidingDefWindow(defC, forceC, yieldInfo, methodDef, fitCfg);
    case "percent_def_span"
        r = fitDefSpanMeanSlope(defC, forceC, yieldInfo, methodDef, fitCfg);
    otherwise
        r.message = sprintf("未知の変形 type: %s", methodDef.type);
end

if r.success
    r.fLowN = nan;
    r.fHighN = nan;
    r.fLowEffN = nan;
end

end

function [mask, desc] = buildPercentDefMask(defC, yieldInfo, methodDef)
yieldDef = yieldInfo.yieldDefMm;
spanDef = yieldDef - defC(1);
if spanDef <= 0
    mask = false(size(defC));
    desc = "降伏変形が接触変形以下";
    return;
end
defLow = defC(1) + methodDef.lowFrac * spanDef;
defHigh = defC(1) + methodDef.highFrac * spanDef;
mask = defC >= defLow & defC <= defHigh;
desc = sprintf("def %.3f-%.3f mm", defLow, defHigh);
end

function r = fitSlidingDefWindow(defC, forceC, yieldInfo, methodDef, fitCfg)
r = emptyDefKrResult();
yieldDef = yieldInfo.yieldDefMm;
spanDef = yieldDef - defC(1);
if spanDef <= 0
    r.message = "降伏変形が接触変形以下";
    return;
end

if methodDef.key == "def_r2_fixed1mm"
    winMm = methodDef.lowFrac;
else
    winMm = max(methodDef.lowN, methodDef.lowFrac * spanDef);
end

if spanDef < winMm
    r.message = sprintf("変形幅 %.3f < 窓幅 %.3f mm", spanDef, winMm);
    return;
end

defStepMm = 0.02;
tiers = fitCfg.krFit.tiers;
lastMsg = "";
for ti = 1:numel(tiers)
    tier = tiers(ti);
    tierCfg = struct( ...
        "minPointsPerFit", tier.minPoints, ...
        "minR2", tier.minR2, ...
        "requirePositiveSlope", fitCfg.krFit.requirePositiveSlope);
    best = findBestSlidingWindow(defC, forceC, winMm, defStepMm, tierCfg);
    if best.success
        r = packDefResult(best, ti, tier.name);
        return;
    end
    lastMsg = best.message;
end

r.message = lastMsg;
if isempty(lastMsg)
    r.message = "sliding 窓フィット失敗";
end
end

function best = findBestSlidingWindow(defC, forceC, winMm, defStepMm, tierCfg)
best = struct("success", false, "message", "", "kr_N_per_mm", nan, ...
    "r2", nan, "nPoints", 0);
bestR2 = -inf;

defMin = defC(1);
defMax = defC(end);
if (defMax - defMin) < winMm
    best.message = sprintf("変形幅 %.3f < 窓幅 %.3f", defMax - defMin, winMm);
    return;
end

for s = defMin:defStepMm:(defMax - winMm)
    winEnd = s + winMm;
    mask = defC >= s & defC <= winEnd;
    attempt = fitLinearMaskedDef(defC, forceC, mask, tierCfg);
    if attempt.success && attempt.r2 > bestR2
        bestR2 = attempt.r2;
        best = attempt;
    end
end

if ~best.success
    best.message = sprintf("R2 条件を満たす窓なし (win=%.2f mm)", winMm);
end
end

function r = fitDefSpanMeanSlope(defC, forceC, yieldInfo, methodDef, fitCfg)
r = emptyDefKrResult();
if ~isfield(yieldInfo, "idxLoadEnd") || ~isfinite(yieldInfo.idxLoadEnd)
    r.message = "idxLoadEnd がありません";
    return;
end

idxEnd = min(yieldInfo.idxLoadEnd, numel(defC));
idxStart = yieldInfo.idxContact;
if idxEnd <= idxStart
    r.message = "loading 区間が短すぎます";
    return;
end

defSeg = defC(idxStart:idxEnd);
forceSeg = forceC(idxStart:idxEnd);
nSeg = numel(defSeg);

tiers = fitCfg.krFit.tiers;
lastMsg = "";
for ti = 1:numel(tiers)
    tier = tiers(ti);
    iLocal0 = max(1, round(methodDef.lowFrac * (nSeg - 1)) + 1);
    iLocal1 = max(iLocal0 + 1, round(methodDef.highFrac * (nSeg - 1)) + 1);
    if (iLocal1 - iLocal0 + 1) < tier.minPoints
        lastMsg = sprintf("中域点数 %d < %d", iLocal1 - iLocal0 + 1, tier.minPoints);
        continue;
    end

    x = defSeg(iLocal0:iLocal1);
    y = forceSeg(iLocal0:iLocal1);
    if range(x) <= eps
        lastMsg = "中域変形幅ゼロ";
        continue;
    end

    dDef = diff(x);
    dForce = diff(y);
    slopes = dForce ./ dDef;
    ok = isfinite(slopes) & (abs(dDef) > eps);
    if ~any(ok)
        lastMsg = "有効な局所傾きなし";
        continue;
    end

    kr = mean(slopes(ok));
    if ~(isfinite(kr) && kr > 0)
        lastMsg = "平均傾きが非正";
        continue;
    end

    intercept = mean(y) - kr * mean(x);
    yhat = kr * x + intercept;
    ssRes = sum((y - yhat).^2);
    ssTot = sum((y - mean(y)).^2);
    if ssTot <= eps
        r2 = 1;
    else
        r2 = 1 - ssRes / ssTot;
    end

    if isfinite(tier.minR2) && r2 < tier.minR2
        lastMsg = sprintf("R2=%.4f < %.2f", r2, tier.minR2);
        continue;
    end

  attempt = struct("success", true, "kr_N_per_mm", kr, "krChord_N_per_mm", (y(end)-y(1))/(x(end)-x(1)), "r2", r2, ...
        "nPoints", numel(x), "message", "ok");
    r = packDefResult(attempt, ti, tier.name);
    return;
end

r.message = lastMsg;
if isempty(lastMsg)
    r.message = "def span 平均傾き失敗";
end
end

function r = fitMaskedWithCascade(defC, forceC, mask, fitCfg, bandDesc)
r = emptyDefKrResult();
if ~any(mask)
    r.message = sprintf("%s: 帯域内点数ゼロ", bandDesc);
    return;
end

tiers = fitCfg.krFit.tiers;
lastMsg = "";
lastR2 = nan;
lastN = nnz(mask);
for ti = 1:numel(tiers)
    tier = tiers(ti);
    tierCfg = struct( ...
        "minPointsPerFit", tier.minPoints, ...
        "minR2", tier.minR2, ...
        "requirePositiveSlope", fitCfg.krFit.requirePositiveSlope);
    attempt = fitLinearMaskedDef(defC, forceC, mask, tierCfg);
    if isfinite(attempt.r2)
        lastR2 = attempt.r2;
    end
    if attempt.nPoints > 0
        lastN = attempt.nPoints;
    end
    if attempt.success
        r = packDefResult(attempt, ti, tier.name);
        return;
    end
    lastMsg = attempt.message;
end

r.message = lastMsg;
r.r2 = lastR2;
r.nBandPoints = lastN;
if isempty(lastMsg)
    r.message = sprintf("%s: カスケード全段階失敗", bandDesc);
end
end

function attempt = fitLinearMaskedDef(defC, forceC, mask, tierCfg)
attempt = struct("success", false, "kr_N_per_mm", nan, "krChord_N_per_mm", nan, "r2", nan, ...
    "nPoints", 0, "message", "");
idx = find(mask);
attempt.nPoints = numel(idx);
if attempt.nPoints < tierCfg.minPointsPerFit
    attempt.message = "点数不足";
    return;
end

x = defC(idx);
y = forceC(idx);
if range(x) <= eps
    attempt.message = "変形幅ゼロ";
    return;
end

p = polyfit(x, y, 1);
yhat = polyval(p, x);
ssRes = sum((y - yhat).^2);
ssTot = sum((y - mean(y)).^2);
if ssTot <= eps
    r2 = 1;
else
    r2 = 1 - ssRes / ssTot;
end
attempt.r2 = r2;

if isfinite(tierCfg.minR2) && r2 < tierCfg.minR2
    attempt.message = sprintf("R2=%.4f", r2);
    return;
end
if tierCfg.requirePositiveSlope && p(1) <= 0
    attempt.message = "傾き非正";
    return;
end

attempt.success = true;
attempt.kr_N_per_mm = p(1);
attempt.krChord_N_per_mm = (y(end) - y(1)) / (x(end) - x(1));
attempt.message = "ok";
end

function r = packDefResult(attempt, tierIdx, tierName)
r = emptyDefKrResult();
r.success = true;
r.kr_N_per_mm = attempt.kr_N_per_mm;
r.krChord_N_per_mm = attempt.krChord_N_per_mm;
r.message = "ok";
r.fitTier = tierIdx;
r.fitTierName = tierName;
r.nBandPoints = attempt.nPoints;
r.r2 = attempt.r2;
end

function r = emptyDefKrResult()
r = struct( ...
    "success", false, ...
    "kr_N_per_mm", nan, ...
    "krChord_N_per_mm", nan, ...
    "message", "", ...
    "fitTier", 0, ...
    "fitTierName", "", ...
    "nBandPoints", 0, ...
    "r2", nan, ...
    "fLowN", nan, ...
    "fHighN", nan, ...
    "fLowEffN", nan);
end
