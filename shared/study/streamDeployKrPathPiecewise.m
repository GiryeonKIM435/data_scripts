function krPath = streamDeployKrPathPiecewise(ctx, yTrueAbs, lowMethodDef, highMethodDef, ...
    switchForceN, fitCfg, sampleOpts)
%streamDeployKrPathPiecewise 力閾値で kr 帯域を切り替えるストリーミング軌跡

if nargin < 7 || isempty(sampleOpts)
    sampleOpts = struct();
end

krVariant = "chord";
if isfield(sampleOpts, "krVariant") && strlength(string(sampleOpts.krVariant)) > 0
    krVariant = char(string(sampleOpts.krVariant));
end

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

policy = resolveStreamDeployPolicy(sampleOpts);
minBandPoints = policy.minBandPointsForKr;

contactYieldInfo = [];
if isfield(ctx, "yieldInfo") && isstruct(ctx.yieldInfo)
    contactYieldInfo = ctx.yieldInfo;
end

krPath = initPiecewiseKrPathStruct(T, yTrueAbs, yTrueRel, forceOffsetN, krVariant, switchForceN);

stateLow = emptyRegimeState();
stateHigh = emptyRegimeState();
hadValidKr = false;

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

    if forceAbs < switchForceN
        methodDef = lowMethodDef;
        state = stateLow;
        krPath.regime(t) = 1;
    else
        methodDef = highMethodDef;
        state = stateHigh;
        krPath.regime(t) = 2;
    end

    defP = defAdj(1:t);
    forceP = forceAdj(1:t);
    yieldInfo = buildStreamingYieldInfo(defP, forceP, filtItem, fitCfg, contactYieldInfo);
    bandMask = computeStreamBandMask(defP, forceP, [], yieldInfo, methodDef, fitCfg);

    [state.krCached, state.lastBandMask, ~, ~] = maybeRefitStreamingKr( ...
        state.krCached, state.lastBandMask, bandMask, minBandPoints, ...
        @() fitKrBand(defP, forceP, yieldInfo, methodDef, fitCfg, [], []), krVariant);

    if forceAbs < switchForceN
        stateLow = state;
    else
        stateHigh = state;
    end

    krCached = state.krCached;
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

function krPath = initPiecewiseKrPathStruct(T, yTrueAbs, yTrueRel, forceOffsetN, krVariant, switchForceN)
krPath = struct();
krPath.force = nan(T, 1);
krPath.forceAbs = nan(T, 1);
krPath.krDeploy = nan(T, 1);
krPath.regime = nan(T, 1);
krPath.krVariant = char(string(krVariant));
krPath.switchForceN = switchForceN;
krPath.nSteps = T;
krPath.yTrue = yTrueAbs;
krPath.yTrueRel = yTrueRel;
krPath.forceOffsetN = forceOffsetN;
krPath.crossStep = nan;
krPath.crossOutcome = "";
krPath.firstKrStep = nan;
krPath.firstKrSec = nan;

end

function state = emptyRegimeState()
state = struct("krCached", nan, "lastBandMask", false(0, 1));

end
