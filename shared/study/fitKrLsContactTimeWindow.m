function out = fitKrLsContactTimeWindow(ctx, tLow, tHigh, fitCfg, krVariant)
%fitKrLsContactTimeWindow 接触後 sec 帯域で LS kr を推定

if nargin < 5 || isempty(krVariant)
    krVariant = "ls";
end

def = ctx.def(:);
force = ctx.force(:);
sec = ctx.sec(:);
yieldInfo = [];
if isfield(ctx, "yieldInfo") && isstruct(ctx.yieldInfo)
    yieldInfo = ctx.yieldInfo;
end
if isempty(yieldInfo)
    yieldInfo = struct("idxContact", 1);
end

methodDef = struct( ...
    "type", "time_abs", ...
    "lowSec", double(tLow), ...
    "highSec", double(tHigh), ...
    "gridValid", true, ...
    "key", "legacy_q4", ...
    "label", sprintf("[%.2f, %.2f) s", tLow, tHigh));

rr = fitKrBand(def, force, yieldInfo, methodDef, fitCfg, sec, []);
kr = extractDeployKr(rr, krVariant);

out = struct();
out.success = logical(rr.success) && isfinite(kr);
out.kr = kr;
out.nBand = rr.nBandPoints;
out.r2 = rr.r2;
out.fitTier = rr.fitTier;
out.tLowSec = tLow;
out.tHighSec = tHigh;
if isfield(rr, "message")
    out.message = string(rr.message);
else
    out.message = "";
end

end
