function krPath = streamDeployKrPath(ctx, yTrueAbs, methodDef, fitCfg, sampleOpts)
%streamDeployKrPath sec 昇順ストリーミングの kr 軌跡（a,b・α 非依存）

if nargin < 5 || isempty(sampleOpts)
    sampleOpts = struct();
end

krVariant = resolveStreamKrVariant(sampleOpts);

if isfield(ctx, "yTrueAbs") && isfinite(ctx.yTrueAbs)
    yTrueAbs = double(ctx.yTrueAbs);
else
    yTrueAbs = double(yTrueAbs);
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
filtItem = ctx.filtItem;
T = numel(defAdj);

if string(methodDef.type) == "percent_yield"
    krPath = streamPercentYieldCausal(ctx, yTrueAbs, yTrueRel, forceOffsetN, ...
        defAdj, forceAdj, secAll, filtItem, methodDef, fitCfg, sampleOpts, krVariant);
    return;
end

if string(methodDef.type) == "time_abs" || string(methodDef.type) == "time_trailing"
    krPath = streamTimeAbsPath(ctx, yTrueAbs, yTrueRel, forceOffsetN, ...
        defAdj, forceAdj, secAll, filtItem, methodDef, fitCfg, sampleOpts, krVariant);
    return;
end

if string(methodDef.type) == "force_abs" || string(methodDef.type) == "force_trailing"
    krPath = streamForceAbsPath(ctx, yTrueAbs, yTrueRel, forceOffsetN, ...
        defAdj, forceAdj, secAll, filtItem, methodDef, fitCfg, sampleOpts, krVariant);
    return;
end

error("streamDeployKrPath:UnsupportedType", "未対応の type: %s", methodDef.type);

end

function krVariant = resolveStreamKrVariant(sampleOpts)
krVariant = "chord";
if isfield(sampleOpts, "krVariant") && strlength(string(sampleOpts.krVariant)) > 0
    krVariant = char(string(sampleOpts.krVariant));
end
end

function krPath = streamForceAbsPath(ctx, yTrueAbs, yTrueRel, forceOffsetN, ...
    defAdj, forceAdj, secAll, filtItem, methodDef, fitCfg, sampleOpts, krVariant)

if nargin < 11 || isempty(sampleOpts)
    sampleOpts = struct();
end
if nargin < 12 || isempty(krVariant)
    krVariant = resolveStreamKrVariant(sampleOpts);
end
policy = resolveStreamDeployPolicy(sampleOpts);
minBandPoints = policy.minBandPointsForKr;

T = numel(defAdj);
contactYieldInfo = [];
if isfield(ctx, "yieldInfo") && isstruct(ctx.yieldInfo)
    contactYieldInfo = ctx.yieldInfo;
end

krPath = initKrPathStruct(T, yTrueAbs, yTrueRel, forceOffsetN, krVariant);

hadValidKr = false;
lastBandMask = false(0, 1);
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

    defP = defAdj(1:t);
    forceP = forceAdj(1:t);
    yieldInfo = buildStreamingYieldInfo(defP, forceP, filtItem, fitCfg, contactYieldInfo);
    bandMask = computeStreamBandMask(defP, forceP, [], yieldInfo, methodDef, fitCfg);

    [krCached, lastBandMask, ~, ~] = maybeRefitStreamingKr( ...
        krCached, lastBandMask, bandMask, minBandPoints, ...
        @() fitKrBand(defP, forceP, yieldInfo, methodDef, fitCfg, [], []), krVariant);

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

function krPath = streamTimeAbsPath(ctx, yTrueAbs, yTrueRel, forceOffsetN, ...
    defAdj, forceAdj, secAll, filtItem, methodDef, fitCfg, sampleOpts, krVariant)

if nargin < 11 || isempty(sampleOpts)
    sampleOpts = struct();
end
if nargin < 12 || isempty(krVariant)
    krVariant = resolveStreamKrVariant(sampleOpts);
end
policy = resolveStreamDeployPolicy(sampleOpts);
minBandPoints = policy.minBandPointsForKr;

T = numel(defAdj);
contactYieldInfo = [];
if isfield(ctx, "yieldInfo") && isstruct(ctx.yieldInfo)
    contactYieldInfo = ctx.yieldInfo;
end

krPath = initKrPathStruct(T, yTrueAbs, yTrueRel, forceOffsetN, krVariant);

hadValidKr = false;
lastBandMask = false(0, 1);
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

    defP = defAdj(1:t);
    forceP = forceAdj(1:t);
    secP = secAll(1:t);
    yieldInfo = buildStreamingYieldInfo(defP, forceP, filtItem, fitCfg, contactYieldInfo);
    bandMask = computeStreamBandMask(defP, forceP, secP, yieldInfo, methodDef, fitCfg);

    [krCached, lastBandMask, ~, ~] = maybeRefitStreamingKr( ...
        krCached, lastBandMask, bandMask, minBandPoints, ...
        @() fitKrBand(defP, forceP, yieldInfo, methodDef, fitCfg, secP, []), krVariant);

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

function krPath = streamPercentYieldCausal(ctx, yTrueAbs, yTrueRel, forceOffsetN, ...
    defAdj, forceAdj, secAll, filtItem, methodDef, fitCfg, sampleOpts, krVariant)

T = numel(defAdj);
krPath = initKrPathStruct(T, yTrueAbs, yTrueRel, forceOffsetN, krVariant);
krPath.yHat = nan(T, 1);
krPath.bandLowAbs = nan(T, 1);
krPath.bandHighAbs = nan(T, 1);

yminCohortAbs = nan;
calibA = nan;
calibB = nan;
if isfield(sampleOpts, "yminCohortAbs") && isfinite(sampleOpts.yminCohortAbs)
    yminCohortAbs = double(sampleOpts.yminCohortAbs);
elseif isfield(sampleOpts, "yminTrainAbs") && isfinite(sampleOpts.yminTrainAbs)
    yminCohortAbs = double(sampleOpts.yminTrainAbs);
end
if isfield(sampleOpts, "calibA") && isfinite(sampleOpts.calibA)
    calibA = double(sampleOpts.calibA);
end
if isfield(sampleOpts, "calibB") && isfinite(sampleOpts.calibB)
    calibB = double(sampleOpts.calibB);
end
if ~isfinite(yminCohortAbs)
    error("streamDeployKrPath:MissingYmin", ...
        "percent_yield には sampleOpts.yminCohortAbs が必要です。");
end
policy = resolveStreamDeployPolicy(sampleOpts);
bandGatePoints = policy.percentYieldBandGatePoints;

contactYieldInfo = [];
if isfield(ctx, "yieldInfo") && isstruct(ctx.yieldInfo)
    contactYieldInfo = ctx.yieldInfo;
end

hadValidKr = false;
krCached = nan;
yHatPrevAbs = yminCohortAbs;

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

    defP = defAdj(1:t);
    forceP = forceAdj(1:t);
    yieldForceNRel = max(0, yminCohortAbs - forceOffsetN);
    yieldInfo = buildCausalYieldInfo(defP, forceP, filtItem, fitCfg, ...
        contactYieldInfo, yieldForceNRel);
    [~, fHigh, fLowEff] = resolveKrBandLimits(yieldInfo, methodDef, fitCfg);
    if isfinite(fLowEff)
        krPath.bandLowAbs(t) = fLowEff + forceOffsetN;
    end
    if isfinite(fHigh)
        krPath.bandHighAbs(t) = fHigh + forceOffsetN;
    end

    bandMask = computeStreamBandMask(defP, forceP, [], yieldInfo, methodDef, fitCfg);
    nBand = sum(bandMask);

    if nBand >= bandGatePoints
        rr = fitKrBand(defP, forceP, yieldInfo, methodDef, fitCfg, [], []);
        krNew = extractDeployKr(rr, krVariant);
        if isfinite(krNew)
            krCached = krNew;
        end
        if isfinite(krCached)
            if ~hadValidKr
                hadValidKr = true;
                krPath.firstKrStep = t;
                krPath.firstKrSec = secAll(t);
            end
        end
        if isfinite(krCached) && isfinite(calibA) && isfinite(calibB)
            yHatAbs = calibA * krCached + calibB;
        elseif isfinite(yHatPrevAbs)
            yHatAbs = yHatPrevAbs;
        else
            yHatAbs = yminCohortAbs;
        end
    else
        yHatAbs = yminCohortAbs;
    end

    krPath.krDeploy(t) = krCached;
    krPath.yHat(t) = yHatAbs;
    yHatPrevAbs = yHatAbs;
end

end

function krPath = initKrPathStruct(T, yTrueAbs, yTrueRel, forceOffsetN, krVariant)
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
