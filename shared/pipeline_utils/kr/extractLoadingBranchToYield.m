function [defLoad, forceLoad, idxLoad, yieldInfo, secLoad] = extractLoadingBranchToYield(y, filtItem, cfg)
%EXTRACTLOADINGBRANCHTOYIELD 降伏までの loading 枝を抽出

sigmaNoiseN = cfg.sigmaNoiseN;
krContact = cfg.krContact;
if ~isfield(cfg, "krContact") || isempty(cfg.krContact)
    krContact = KrContactConfig();
end
zeroAtContact = isfield(krContact, "zeroAtContact") && krContact.zeroAtContact;

zeroAdjust = true;
if isfield(cfg, "zeroAdjustFirstPoint")
    zeroAdjust = cfg.zeroAdjustFirstPoint;
else
    zeroAdjust = getZeroAdjustEnabled(cfg);
end
if zeroAtContact
    zeroAdjust = false;
end

def = y.deformation(:);
force = y.force(:);
if isfield(y, "sec")
    sec = y.sec(:);
else
    sec = nan(size(def));
end
valid = isfinite(def) & isfinite(force);
def = def(valid);
force = force(valid);
sec = sec(valid);
defOffsetFirst = 0;
forceOffsetFirst = 0;
if zeroAtContact && ~isempty(def)
    defOffsetFirst = def(1);
    forceOffsetFirst = force(1);
end
[def, force, offsetMeta] = zeroAdjustDefForceFirstPoint(def, force, zeroAdjust);
idxOrig = (1:numel(def)).';

yieldDefMm = nan;
yieldForceN = nan;
yd = filtItem.yieldDropThreshold;
if isfield(yd, "hasYield") && yd.hasYield
    yieldDefMm = yd.deformation;
    yieldForceN = yd.force;
    if zeroAtContact
        yieldDefMm = yieldDefMm + defOffsetFirst;
        yieldForceN = yieldForceN + forceOffsetFirst;
    end
end
if ~(isfinite(yieldDefMm) && isfinite(yieldForceN))
    error("extractLoadingBranchToYield:NoYield", "降伏点情報がありません");
end

[~, idxPeakDef] = max(def);
idxLoadEnd = idxPeakDef;
for k = 2:idxPeakDef
    if def(k) >= yieldDefMm
        idxLoadEnd = k;
        break;
    end
end

defLoad = def(1:idxLoadEnd);
forceLoad = force(1:idxLoadEnd);
secLoad = sec(1:idxLoadEnd);
idxLoad = idxOrig(1:idxLoadEnd);

[idxContact, riseInfo] = detectForceRiseOnset(defLoad, forceLoad, sigmaNoiseN, krContact);

defAtContact = defLoad(idxContact);
forceAtContact = forceLoad(idxContact);
secAtContact = secLoad(idxContact);
if zeroAtContact
    defLoad = defLoad(idxContact:end);
    forceLoad = forceLoad(idxContact:end);
    secLoad = secLoad(idxContact:end);
    idxLoad = idxLoad(idxContact:end);
    defLoad = defLoad - defAtContact;
    forceLoad = forceLoad - forceAtContact;
    if isfinite(secAtContact)
        secLoad = secLoad - secAtContact;
    end
    yieldDefMm = yieldDefMm - defAtContact;
    yieldForceN = yieldForceN - forceAtContact;
    idxContact = 1;
end

yieldInfo = struct( ...
    "yieldDefMm", yieldDefMm, ...
    "yieldForceN", yieldForceN, ...
    "idxContact", idxContact, ...
    "riseDetectMethod", riseInfo.method, ...
    "slopeThrObvious", riseInfo.slopeThrObvious, ...
    "riseDetected", riseInfo.detected);
if isfield(riseInfo, "slackDeltaThrN")
    yieldInfo.slackDeltaThrN = riseInfo.slackDeltaThrN;
end

if isfield(riseInfo, "obviousRunStart")
    yieldInfo.obviousRunStart = riseInfo.obviousRunStart;
end
if isfield(riseInfo, "obviousRunEnd")
    yieldInfo.obviousRunEnd = riseInfo.obviousRunEnd;
end
if isfield(riseInfo, "slackRunStart")
    yieldInfo.slackRunStart = riseInfo.slackRunStart;
end
if isfield(riseInfo, "slackRunEnd")
    yieldInfo.slackRunEnd = riseInfo.slackRunEnd;
end
if offsetMeta.applied
    yieldInfo.defOffsetMm = offsetMeta.defOffsetMm;
    yieldInfo.forceOffsetN = offsetMeta.forceOffsetN;
end
if zeroAtContact
    yieldInfo.zeroAdjustMethod = "contact";
    yieldInfo.defOffsetFirstMm = defOffsetFirst;
    yieldInfo.forceOffsetFirstN = forceOffsetFirst;
end
yieldInfo.contactDefBeforeZero = defAtContact;
yieldInfo.contactForceBeforeZero = forceAtContact;
yieldInfo.contactForceN = forceLoad(idxContact);
yieldInfo.contactDefMm = defLoad(idxContact);
yieldInfo.zeroAtContact = zeroAtContact;
if isfield(riseInfo, "fallback")
    yieldInfo.riseFallback = riseInfo.fallback;
end

if zeroAtContact
    yieldInfo.idxLoadEnd = idxLoadEnd - idxContact + 1;
else
    yieldInfo.idxLoadEnd = idxLoadEnd;
end

end
