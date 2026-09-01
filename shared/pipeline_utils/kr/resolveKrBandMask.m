function [mask, meta] = resolveKrBandMask(defC, forceC, yieldInfo, methodDef, fitCfg, secC)
%RESOLVEKRBANDMASK 方式別のフィット帯域マスク（接触後座標系）

if nargin < 5 || isempty(fitCfg)
    fitCfg = struct("krFit", KrFitConfig());
end
if nargin < 6
    secC = [];
end

defC = defC(:);
forceC = forceC(:);
mask = false(numel(defC), 1);
meta = struct("type", methodDef.type, "isForceBand", true, "label", methodDef.label);

switch methodDef.type
    case {"percent_yield", "force_abs"}
        [fLow, fHigh, fLowEff] = resolveKrBandLimits(yieldInfo, methodDef, fitCfg);
        mask = forceC >= fLowEff & forceC <= fHigh;
        meta.fLowN = fLow;
        meta.fHighN = fHigh;
        meta.fLowEffN = fLowEff;

    case "time_abs"
        meta.isForceBand = false;
        if isempty(secC)
            secC = nan(size(defC));
        end
        secC = secC(:);
        if numel(secC) < numel(defC)
            secC(end + 1:numel(defC), 1) = nan; %#ok<AGROW>
        end
        [mask, meta] = maskTimeAbs(secC, methodDef, meta);

    case "time_trailing"
        meta.isForceBand = false;
        if isempty(secC)
            secC = nan(size(defC));
        end
        secC = secC(:);
        if numel(secC) < numel(defC)
            secC(end + 1:numel(defC), 1) = nan; %#ok<AGROW>
        end
        [mask, meta] = maskTimeTrailing(secC, methodDef, meta);

    case "force_trailing"
        [fLow, fHigh, fLowEff] = maskForceTrailing(forceC, yieldInfo, methodDef, fitCfg, meta);
        if isfinite(fLowEff) && isfinite(fHigh)
            mask = isfinite(forceC) & forceC >= fLowEff & forceC < fHigh;
        else
            mask = false(size(forceC));
        end
        meta.fLowN = fLow;
        meta.fHighN = fHigh;
        meta.fLowEffN = fLowEff;

    case "percent_def"
        meta.isForceBand = false;
        [mask, meta] = maskPercentDef(defC, yieldInfo, methodDef, meta);

    case "percent_def_span"
        meta.isForceBand = false;
        [mask, meta] = maskPercentDefSpan(defC, forceC, yieldInfo, methodDef, meta);

    case "sliding_def"
        meta.isForceBand = false;
        meta.skipped = true;
        meta.reason = "sliding_def は可変窓のため静的マスク未対応";

    otherwise
        error("resolveKrBandMask:BadType", "未知の type: %s", methodDef.type);
end

end

function [mask, meta] = maskTimeAbs(secC, methodDef, meta)
tLow = methodDef.lowSec;
tHigh = methodDef.highSec;
mask = isfinite(secC) & secC >= tLow & secC <= tHigh;
meta.tLowSec = tLow;
meta.tHighSec = tHigh;
end

function [mask, meta] = maskTimeTrailing(secC, methodDef, meta)
anchorSec = secC(find(isfinite(secC), 1, "last"));
[tLow, tHigh, trailMeta] = resolveKrTrailingBandLimits(methodDef, anchorSec, nan);
mask = isfinite(secC) & isfinite(tLow) & isfinite(tHigh) & secC >= tLow & secC < tHigh;
meta.tLowSec = tLow;
meta.tHighSec = tHigh;
meta.anchorSec = anchorSec;
if isfield(trailMeta, "offsetSec")
    meta.offsetSec = trailMeta.offsetSec;
    meta.widthSec = trailMeta.widthSec;
end
end

function [fLow, fHigh, fLowEff] = maskForceTrailing(forceC, yieldInfo, methodDef, fitCfg, meta)
anchorForce = forceC(find(isfinite(forceC), 1, "last"));
[fLow, fHigh, trailMeta] = resolveKrTrailingBandLimits(methodDef, nan, anchorForce);
fLowEff = fLow;
if isfinite(fLow) && isfield(fitCfg, "krFit") && fitCfg.krFit.clampBandLowToContact && ...
        isfield(yieldInfo, "contactForceN") && isfinite(yieldInfo.contactForceN)
    fLowEff = max(fLow, yieldInfo.contactForceN);
end
if nargin >= 5 && isstruct(meta)
    meta.anchorForceN = anchorForce;
    if isfield(trailMeta, "offsetN")
        meta.offsetN = trailMeta.offsetN;
        meta.widthN = trailMeta.widthN;
    end
end
end

function [mask, meta] = maskPercentDef(defC, yieldInfo, methodDef, meta)
yieldDef = yieldInfo.yieldDefMm;
spanDef = yieldDef - defC(1);
if spanDef <= 0
    mask = false(size(defC));
    return;
end
defLow = defC(1) + methodDef.lowFrac * spanDef;
defHigh = defC(1) + methodDef.highFrac * spanDef;
mask = defC >= defLow & defC <= defHigh;
meta.defLowMm = defLow;
meta.defHighMm = defHigh;
end

function [mask, meta] = maskPercentDefSpan(defC, forceC, yieldInfo, methodDef, meta)
if ~isfield(yieldInfo, "idxLoadEnd") || ~isfinite(yieldInfo.idxLoadEnd)
    mask = false(size(defC));
    return;
end
idxEnd = min(yieldInfo.idxLoadEnd, numel(defC));
idxStart = yieldInfo.idxContact;
if idxEnd <= idxStart
    mask = false(size(defC));
    return;
end
defSeg = defC(idxStart:idxEnd);
nSeg = numel(defSeg);
iLocal0 = max(1, round(methodDef.lowFrac * (nSeg - 1)) + 1);
iLocal1 = max(iLocal0 + 1, round(methodDef.highFrac * (nSeg - 1)) + 1);
mask = false(size(defC));
mask(idxStart + iLocal0 - 1:idxStart + iLocal1 - 1) = true;
meta.defLowMm = defSeg(iLocal0);
meta.defHighMm = defSeg(iLocal1);
if any(mask)
    meta.forceLowN = min(forceC(mask));
    meta.forceHighN = max(forceC(mask));
end
end
