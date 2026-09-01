function [low, high, meta] = resolveKrTrailingBandLimits(methodDef, anchorSec, anchorForce)
%resolveKrTrailingBandLimits trailing 帯域 [anchor−offset−width, anchor−offset)

meta = struct("type", string(methodDef.type));
low = nan;
high = nan;

switch string(methodDef.type)
    case "time_trailing"
        n = methodDef.offsetSec;
        w = methodDef.widthSec;
        if ~(isfinite(anchorSec) && isfinite(n) && isfinite(w) && w > 0 && n >= 0)
            return;
        end
        high = anchorSec - n;
        low = high - w;
        meta.offsetSec = n;
        meta.widthSec = w;
        meta.anchorSec = anchorSec;
        meta.tLowSec = low;
        meta.tHighSec = high;

    case "force_trailing"
        f = methodDef.offsetN;
        w = methodDef.widthN;
        if ~(isfinite(anchorForce) && isfinite(f) && isfinite(w) && w > 0 && f >= 0)
            return;
        end
        high = anchorForce - f;
        low = high - w;
        meta.offsetN = f;
        meta.widthN = w;
        meta.anchorForceN = anchorForce;
        meta.fLowN = low;
        meta.fHighN = high;

    otherwise
        error("resolveKrTrailingBandLimits:BadType", "未知の type: %s", methodDef.type);
end

end
