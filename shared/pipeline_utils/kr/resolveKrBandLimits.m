function [fLow, fHigh, fLowEff] = resolveKrBandLimits(yieldInfo, methodDef, fitCfg)
%RESOLVEKRBANDLIMITS kr フィット帯域の力下限・上限（toe clamp 含む）

if methodDef.type == "percent_yield"
    fLow = methodDef.lowFrac * yieldInfo.yieldForceN;
    fHigh = methodDef.highFrac * yieldInfo.yieldForceN;
elseif methodDef.type == "force_abs"
    fLow = methodDef.lowN;
    fHigh = methodDef.highN;
elseif methodDef.type == "time_abs"
    fLow = nan;
    fHigh = nan;
elseif methodDef.type == "force_trailing"
    fLow = nan;
    fHigh = nan;
elseif methodDef.type == "time_trailing"
    fLow = nan;
    fHigh = nan;
elseif ismember(methodDef.type, ["percent_def", "sliding_def", "percent_def_span"])
    fLow = nan;
    fHigh = nan;
else
    error("resolveKrBandLimits:BadType", "未知の type: %s", methodDef.type);
end

fLowEff = fLow;
if ~isnan(fLow) && nargin >= 3 && isfield(fitCfg, "krFit") && fitCfg.krFit.clampBandLowToContact && ...
        isfield(yieldInfo, "contactForceN") && isfinite(yieldInfo.contactForceN)
    fLowEff = max(fLow, yieldInfo.contactForceN);
end

end
