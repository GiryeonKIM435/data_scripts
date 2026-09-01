function bandMask = computeStreamBandMask(defP, forceP, secP, yieldInfo, methodDef, fitCfg)
%computeStreamBandMask 接触以降 prefix の kr 帯域内点マスク

if nargin < 3
    secP = [];
end

methodType = string(methodDef.type);
idxC = max(1, min(yieldInfo.idxContact, numel(forceP)));

if methodType == "time_abs"
    if isempty(secP)
        secP = nan(size(forceP));
    end
    secC = secP(idxC:end);
    tLow = methodDef.lowSec;
    tHigh = methodDef.highSec;
    bandMask = isfinite(secC) & secC >= tLow & secC <= tHigh;
    return;
end

if methodType == "time_trailing"
    if isempty(secP)
        secP = nan(size(forceP));
    end
    secC = secP(idxC:end);
    anchorSec = secP(end);
    if ~isfinite(anchorSec)
        anchorSec = secC(find(isfinite(secC), 1, "last"));
    end
    [tLow, tHigh, ~] = resolveKrTrailingBandLimits(methodDef, anchorSec, nan);
    bandMask = isfinite(secC) & isfinite(tLow) & isfinite(tHigh) & secC >= tLow & secC < tHigh;
    return;
end

forceC = forceP(idxC:end);
if methodType == "force_trailing"
    anchorForce = forceP(end);
    if ~isfinite(anchorForce)
        anchorForce = forceC(find(isfinite(forceC), 1, "last"));
    end
    [fLow, fHigh, ~] = resolveKrTrailingBandLimits(methodDef, nan, anchorForce);
    fLowEff = fLow;
    if isfinite(fLow) && nargin >= 6 && isfield(fitCfg, "krFit") && fitCfg.krFit.clampBandLowToContact && ...
            isfield(yieldInfo, "contactForceN") && isfinite(yieldInfo.contactForceN)
        fLowEff = max(fLow, yieldInfo.contactForceN);
    end
    if ~(isfinite(fLowEff) && isfinite(fHigh))
        bandMask = false(numel(forceC), 1);
        return;
    end
    bandMask = forceC >= fLowEff & forceC < fHigh;
    return;
end

[fLow, fHigh, fLowEff] = resolveKrBandLimits(yieldInfo, methodDef, fitCfg);
if isnan(fLow) || isnan(fHigh)
    bandMask = false(numel(forceC), 1);
    return;
end
bandMask = forceC >= fLowEff & forceC <= fHigh;

end
