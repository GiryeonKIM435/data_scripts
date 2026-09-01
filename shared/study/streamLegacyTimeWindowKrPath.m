function krPath = streamLegacyTimeWindowKrPath(ctx, yTrueAbs, fitCfg, q4Cfg)
%streamLegacyTimeWindowKrPath 直近 onlineWindowSec の因果 LS kr 軌跡

if nargin < 4 || isempty(q4Cfg)
    error("streamLegacyTimeWindowKrPath:MissingQ4Cfg", "q4Cfg が必要です。");
end

if isfield(ctx, "yTrueAbs") && isfinite(ctx.yTrueAbs)
    yTrueAbs = double(ctx.yTrueAbs);
end
if isfield(ctx, "yTrueRel") && isfinite(ctx.yTrueRel)
    yTrueRel = double(ctx.yTrueRel);
else
    yTrueRel = yTrueAbs;
end
forceOffsetN = 0;
if isfield(ctx, "forceOffsetN") && isfinite(ctx.forceOffsetN)
    forceOffsetN = double(ctx.forceOffsetN);
end

defAdj = ctx.def(:);
forceAdj = ctx.force(:);
secAll = ctx.sec(:);
T = numel(defAdj);
windowSec = q4Cfg.onlineWindowSec;
krVariant = q4Cfg.krVariant;
if ~isfield(q4Cfg, "krVariant") || strlength(string(q4Cfg.krVariant)) == 0
    krVariant = "ls";
end

krPath = initLegacyKrPathStruct(T, yTrueAbs, yTrueRel, forceOffsetN, krVariant);

hadValidKr = false;
lastNBand = 0;
krCached = nan;

for t = 1:T
    forceRel = forceAdj(t);
    forceAbs = forceRel + forceOffsetN;
    krPath.force(t) = forceRel;
    krPath.forceAbs(t) = forceAbs;

    if forceAbs > yTrueAbs
        krPath.crossStep = t;
        if ~hadValidKr
            krPath.crossOutcome = "fail_cross_warmup";
        else
            krPath.crossOutcome = "fail_cross_after_pred";
        end
        break;
    end

    secNow = secAll(t);
    if ~isfinite(secNow)
        krPath.krDeploy(t) = krCached;
        continue;
    end
    tLow = max(0, secNow - windowSec);
    tHigh = secNow;

    defP = defAdj(1:t);
    forceP = forceAdj(1:t);
    secP = secAll(1:t);
    nBand = nnz(isfinite(secP) & secP >= tLow & secP <= tHigh);

    if nBand > lastNBand
        est = fitKrLsContactTimeWindow(struct( ...
            "def", defP, "force", forceP, "sec", secP, ...
            "yieldInfo", ctx.yieldInfo), tLow, tHigh, fitCfg, krVariant);
        lastNBand = nBand;
        if est.success
            krCached = est.kr;
        end
    end

    if isfinite(krCached)
        if ~hadValidKr
            hadValidKr = true;
            krPath.firstKrStep = t;
            krPath.firstKrSec = secAll(t);
        end
    end

    krPath.krDeploy(t) = krCached;
end

end

function krPath = initLegacyKrPathStruct(T, yTrueAbs, yTrueRel, forceOffsetN, krVariant)
krPath = struct();
krPath.force = nan(T, 1);
krPath.forceAbs = nan(T, 1);
krPath.krDeploy = nan(T, 1);
krPath.krVariant = char(string(krVariant));
krPath.nSteps = T;
krPath.yTrue = yTrueAbs;
krPath.yTrueRel = yTrueRel;
krPath.forceOffsetN = forceOffsetN;
krPath.crossStep = nan;
krPath.crossOutcome = "";
krPath.firstKrStep = nan;
krPath.firstKrSec = nan;
end
