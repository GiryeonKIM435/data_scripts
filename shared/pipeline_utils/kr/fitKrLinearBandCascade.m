function r = fitKrLinearBandCascade(defC, forceC, yieldInfo, methodDef, fitCfg)
%FITKRLINEARBANDCASCADE 帯域マスク + カスケード線形フィット

if nargin < 5 || isempty(fitCfg)
    fitCfg = struct();
end
if ~isfield(fitCfg, "krFit") || isempty(fitCfg.krFit)
    fitCfg.krFit = KrFitConfig();
end

idxC = max(1, min(yieldInfo.idxContact, numel(defC)));
defC = defC(idxC:end);
forceC = forceC(idxC:end);

[fLow, fHigh, fLowEff] = resolveKrBandLimits(yieldInfo, methodDef, fitCfg);
mask = forceC >= fLowEff & forceC <= fHigh;
nBand = nnz(mask);

r = struct( ...
    "success", false, ...
    "kr_N_per_mm", nan, ...
    "krChord_N_per_mm", nan, ...
    "message", "", ...
    "fitTier", 0, ...
    "fitTierName", "", ...
    "nBandPoints", nBand, ...
    "r2", nan, ...
    "fLowN", fLow, ...
    "fHighN", fHigh, ...
    "fLowEffN", fLowEff);

if nBand == 0
    r.message = "帯域内点数ゼロ";
    return;
end

tiers = fitCfg.krFit.tiers;
lastMsg = "";
lastR2 = nan;
lastN = nBand;
for ti = 1:numel(tiers)
    tier = tiers(ti);
    tierCfg = struct( ...
        "minPointsPerFit", tier.minPoints, ...
        "minR2", tier.minR2, ...
        "requirePositiveSlope", fitCfg.krFit.requirePositiveSlope);
    attempt = fitLinearMasked(defC, forceC, mask, tierCfg);
    lastMsg = attempt.message;
    if isfinite(attempt.r2)
        lastR2 = attempt.r2;
    end
    if attempt.nPoints > 0
        lastN = attempt.nPoints;
    end
    if attempt.success
        r.success = true;
        r.kr_N_per_mm = attempt.kr_N_per_mm;
        r.krChord_N_per_mm = attempt.krChord_N_per_mm;
        r.message = "ok";
        r.fitTier = ti;
        r.fitTierName = tier.name;
        r.nBandPoints = attempt.nPoints;
        r.r2 = attempt.r2;
        return;
    end
end

r.message = lastMsg;
r.r2 = lastR2;
r.nBandPoints = lastN;
if isempty(lastMsg)
    r.message = "カスケード全段階失敗";
end

end

function r = fitLinearMasked(x, y, mask, cfg)
r = struct("success", false, "kr_N_per_mm", nan, "message", "", ...
    "krChord_N_per_mm", nan, "nPoints", 0, "r2", nan);
idx = find(mask);
r.nPoints = numel(idx);
if r.nPoints < cfg.minPointsPerFit
    r.message = "点数不足";
    return;
end
x = x(idx);
y = y(idx);
if range(x) <= eps
    r.message = "変形幅ゼロ";
    return;
end
p = polyfit(x, y, 1);
yhat = polyval(p, x);
ssRes = sum((y - yhat).^2);
ssTot = sum((y - mean(y)).^2);
r2 = ifelse(ssTot <= eps, 1, 1 - ssRes / ssTot);
r.r2 = r2;
if isfinite(cfg.minR2) && r2 < cfg.minR2
    r.message = sprintf("R2=%.4f", r2);
    return;
end
if isfield(cfg, "requirePositiveSlope") && cfg.requirePositiveSlope && p(1) <= 0
    r.message = "傾き非正";
    return;
end
r.success = true;
r.kr_N_per_mm = p(1);
r.krChord_N_per_mm = (y(end) - y(1)) / (x(end) - x(1));
r.message = "ok";
end

function v = ifelse(c, a, b)
if c
    v = a;
else
    v = b;
end
end
