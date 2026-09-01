function yieldInfo = buildStreamingYieldInfo(defAdj, forceAdj, filtItem, fitCfg, baseYieldInfo)
%buildStreamingYieldInfo ストリーミング prefix 用 yieldInfo（fitKrBand 入力）

sigmaNoiseN = fitCfg.sigmaNoiseN;
krContact = fitCfg.krContact;
if ~isfield(fitCfg, "krContact") || isempty(fitCfg.krContact)
    krContact = KrContactConfig();
end

[idxContact, riseInfo] = detectForceRiseOnset(defAdj, forceAdj, sigmaNoiseN, krContact);
nPrefix = numel(forceAdj);

yieldDefMm = nan;
yieldForceN = nan;
if nargin >= 5 && ~isempty(baseYieldInfo) && isstruct(baseYieldInfo)
    if isfield(baseYieldInfo, "yieldDefMm")
        yieldDefMm = baseYieldInfo.yieldDefMm;
    end
    if isfield(baseYieldInfo, "yieldForceN")
        yieldForceN = baseYieldInfo.yieldForceN;
    end
    if isfield(baseYieldInfo, "idxContact") && isfinite(baseYieldInfo.idxContact) ...
            && baseYieldInfo.idxContact <= nPrefix
        idxContact = baseYieldInfo.idxContact;
    end
else
    yd = filtItem.yieldDropThreshold;
    if isfield(yd, "hasYield") && yd.hasYield
        yieldDefMm = yd.deformation;
        yieldForceN = yd.force;
    end
end

idxContact = max(1, min(idxContact, nPrefix));

yieldInfo = struct();
yieldInfo.yieldDefMm = yieldDefMm;
yieldInfo.yieldForceN = yieldForceN;
yieldInfo.idxContact = idxContact;
yieldInfo.riseDetectMethod = riseInfo.method;
yieldInfo.contactForceN = forceAdj(idxContact);
yieldInfo.contactDefMm = defAdj(idxContact);
yieldInfo.zeroAtContact = isfield(krContact, "zeroAtContact") && krContact.zeroAtContact;
if nargin >= 5 && ~isempty(baseYieldInfo) && isstruct(baseYieldInfo) ...
        && isfield(baseYieldInfo, "zeroAtContact")
    yieldInfo.zeroAtContact = logical(baseYieldInfo.zeroAtContact);
end
if isfield(riseInfo, "detected")
    yieldInfo.riseDetected = riseInfo.detected;
end

end
