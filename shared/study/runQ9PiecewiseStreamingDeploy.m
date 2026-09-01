function pack = runQ9PiecewiseStreamingDeploy(cfg, switchForceN, lowKey, highKey, ...
    calibLow, calibHigh, y, ids, sampleCtx, alphaValues, fitCfg, deployOpts)
%runQ9PiecewiseStreamingDeploy 力閾値レジーム切替デプロイ（レジーム別 LOO 校正）

if nargin < 12 || isempty(deployOpts)
    deployOpts = struct();
end

methods = KrMethodRegistry();
lowMdef = lookupKrMethodRegistry(lowKey, methods);
highMdef = lookupKrMethodRegistry(highKey, methods);
n = numel(y);
nAlpha = numel(alphaValues);

yminCohortAbs = computeCohortYieldMin(y);
isPercentYieldLow = string(lowMdef.type) == "percent_yield";
isPercentYieldHigh = string(highMdef.type) == "percent_yield";

policy = resolveStreamDeployPolicy(struct(), cfg);
krVariant = cfg.deploy.krVariant;
if isfield(cfg, "q9") && isfield(cfg.q9, "krVariant") && strlength(string(cfg.q9.krVariant)) > 0
    krVariant = cfg.q9.krVariant;
end

parallelSamples = false;
if isfield(deployOpts, "parallelSamples")
    parallelSamples = logical(deployOpts.parallelSamples);
end
if isfield(cfg, "q9") && isfield(cfg.q9, "parallelSamples")
    parallelSamples = logical(cfg.q9.parallelSamples);
end

trajFingerprint = struct();
if isfield(deployOpts, "trajFingerprint")
    trajFingerprint = deployOpts.trajFingerprint;
end
cacheDir = "";
if isfield(deployOpts, "trajectoryCacheDir")
    cacheDir = char(deployOpts.trajectoryCacheDir);
end
saveTrajectoryCache = false;
if isfield(deployOpts, "saveTrajectoryCache")
    saveTrajectoryCache = logical(deployOpts.saveTrajectoryCache);
end

[lowLeakCat, lowLeakNote] = krLeakageCategory(lowKey, lowMdef);
[highLeakCat, highLeakNote] = krLeakageCategory(highKey, highMdef);
meta = struct( ...
    "switchForceN", switchForceN, ...
    "lowMethodKey", char(lowKey), ...
    "highMethodKey", char(highKey), ...
    "methodType", char(highMdef.type), ...
    "label", sprintf("F<%.0f:%s, F>=%.0f:%s", switchForceN, lowMdef.label, switchForceN, highMdef.label), ...
    "lowLabel", char(lowMdef.label), ...
    "highLabel", char(highMdef.label), ...
    "lowLeakCategory", char(lowLeakCat), ...
    "lowLeakNote", char(lowLeakNote), ...
    "highLeakCategory", char(highLeakCat), ...
    "highLeakNote", char(highLeakNote));

trajCell = cell(n, 1);
trajCacheLoaded = false;
reuseCache = cfg.cache.enabled;
if isfield(cfg, "q9") && isfield(cfg.q9, "reuseCache")
    reuseCache = logical(cfg.q9.reuseCache);
end
if reuseCache && strlength(string(cacheDir)) > 0 && isfield(trajFingerprint, "hash")
    cached = loadQ9TrajectoryCache(cacheDir, lowKey, highKey, ids, trajFingerprint);
    if cached.hit
        trajCell = cached.trajectories;
        trajCacheLoaded = true;
    end
end

foldOutcomes = cell(nAlpha, 1);
perSampleRows = cell(n * nAlpha, 1);
rowPtr = 0;
nTrajComputed = 0;

emptyOutcome = struct( ...
    "outcome", "", "yTrue", nan, "alpha", nan, "F_stop", nan, ...
    "t_stop", nan, "y_hat_at_stop", nan, "kr_at_stop", nan, ...
    "F_lastUpdate", nan, "F_used", nan, ...
    "nStepsToFirstKr", nan, "secToFirstKr", nan, "hadValidKr", false, ...
    "nStepsTotal", nan, "stopErrorN", nan, "relativeStopError", nan, ...
    "isSafeStop", false, ...
    "stoppingMargin", nan, "stopForceRatio", nan, ...
    "t_finalUpdate", nan, "F_finalUpdate", nan, "y_hat_finalUpdate", nan, ...
    "finalUpdateErrorN", nan, "relativeFinalUpdateError", nan);

for ai = 1:nAlpha
    foldOutcomes{ai} = repmat(emptyOutcome, n, 1);
end

needTrajIdx = find(~q9TrajCacheLoadedSamples(trajCell, n));
if ~isempty(needTrajIdx)
    if parallelSamples
        poolInfo = ensurePaperStudyParallelPool(cfg);
        if poolInfo.active && numel(needTrajIdx) > 1
            built = cell(numel(needTrajIdx), 1);
            parfor ti = 1:numel(needTrajIdx)
                i = needTrajIdx(ti);
                sampleOpts = buildQ9PiecewiseSampleOpts(isPercentYieldLow, isPercentYieldHigh, ...
                    calibLow, calibHigh, yminCohortAbs, i, krVariant, policy);
                built{ti} = streamDeployKrPathPiecewise(sampleCtx{i}, y(i), lowMdef, highMdef, ...
                    switchForceN, fitCfg, sampleOpts);
            end
            for ti = 1:numel(needTrajIdx)
                trajCell{needTrajIdx(ti)} = built{ti};
            end
            nTrajComputed = nTrajComputed + numel(needTrajIdx);
        else
            for ti = 1:numel(needTrajIdx)
                i = needTrajIdx(ti);
                sampleOpts = buildQ9PiecewiseSampleOpts(isPercentYieldLow, isPercentYieldHigh, ...
                    calibLow, calibHigh, yminCohortAbs, i, krVariant, policy);
                trajCell{i} = streamDeployKrPathPiecewise(sampleCtx{i}, y(i), lowMdef, highMdef, ...
                    switchForceN, fitCfg, sampleOpts);
                nTrajComputed = nTrajComputed + 1;
            end
        end
    else
        for ti = 1:numel(needTrajIdx)
            i = needTrajIdx(ti);
            sampleOpts = buildQ9PiecewiseSampleOpts(isPercentYieldLow, isPercentYieldHigh, ...
                calibLow, calibHigh, yminCohortAbs, i, krVariant, policy);
            trajCell{i} = streamDeployKrPathPiecewise(sampleCtx{i}, y(i), lowMdef, highMdef, ...
                switchForceN, fitCfg, sampleOpts);
            nTrajComputed = nTrajComputed + 1;
        end
    end
end

for i = 1:n
    if ~isfinite(calibLow.a(i)) || ~isfinite(calibLow.b(i)) ...
            || ~isfinite(calibHigh.a(i)) || ~isfinite(calibHigh.b(i))
        for ai = 1:nAlpha
            o = emptyOutcome;
            o.outcome = "fail_no_kr";
            o.yTrue = y(i);
            o.alpha = alphaValues(ai);
            foldOutcomes{ai}(i) = o;
            rowPtr = rowPtr + 1;
            perSampleRows{rowPtr} = packQ9PerSampleRow(ids(i), meta, alphaValues(ai), o);
        end
        continue;
    end

    if i <= numel(trajCell) && ~isempty(trajCell{i}) && isstruct(trajCell{i})
        krPath = trajCell{i};
    else
        sampleOpts = buildQ9PiecewiseSampleOpts(isPercentYieldLow, isPercentYieldHigh, ...
            calibLow, calibHigh, yminCohortAbs, i, krVariant, policy);
        krPath = streamDeployKrPathPiecewise(sampleCtx{i}, y(i), lowMdef, highMdef, ...
            switchForceN, fitCfg, sampleOpts);
        trajCell{i} = krPath;
        nTrajComputed = nTrajComputed + 1;
    end

    traj = applyDeployPiecewiseCalibToTrajectory(krPath, y(i), ...
        calibLow.a(i), calibLow.b(i), calibHigh.a(i), calibHigh.b(i), switchForceN);
    for ai = 1:nAlpha
        o = evalStopAlphas(traj, alphaValues(ai), y(i));
        foldOutcomes{ai}(i) = o;
        rowPtr = rowPtr + 1;
        perSampleRows{rowPtr} = packQ9PerSampleRow(ids(i), meta, alphaValues(ai), o);
    end
end

if saveTrajectoryCache && strlength(string(cacheDir)) > 0 && isfield(trajFingerprint, "hash")
    saveQ9TrajectoryCache(cacheDir, lowKey, highKey, ids, trajCell, trajFingerprint);
end

summaryRows = cell(nAlpha, 25);
for ai = 1:nAlpha
    alpha = alphaValues(ai);
    smeta = struct( ...
        "krMethodKey", sprintf("%s|%s@F%.0f", meta.lowMethodKey, meta.highMethodKey, switchForceN), ...
        "alpha", alpha, "methodType", meta.methodType, ...
        "gridStart", highMdef.gridStart, "gridWidth", highMdef.gridWidth, ...
        "gridValid", highMdef.gridValid, "label", meta.label, ...
        "leakCategory", meta.highLeakCategory, "leakNote", meta.highLeakNote);
    srow = summarizeStreamingDeployOutcomes(foldOutcomes{ai}, smeta);
    summaryRows(ai, :) = {srow.krMethodKey, srow.alpha, srow.methodType, ...
        srow.gridStart, srow.gridWidth, srow.gridValid, srow.label, ...
        srow.leakCategory, srow.leakNote, srow.nCohort, srow.nUsed, ...
        srow.safeSuccessRate, srow.safeStopRate, srow.safeStopRate_sem, ...
        srow.fail_cross_warmup, srow.fail_cross_after_pred, ...
        srow.fail_never_stopped, srow.fail_no_kr, ...
        srow.stopMae_success, srow.stopMae_success_sem, srow.stopR2_success, ...
        srow.relativeStopError_success_mean, srow.relativeStopError_success_sem, ...
        srow.warmupStepsMean, srow.warmupSteps_sem};
end

pack = struct();
pack.summaryRows = summaryRows;
pack.perSampleRows = perSampleRows(1:rowPtr);
pack.calibLow = calibLow;
pack.calibHigh = calibHigh;
pack.foldOutcomes = {foldOutcomes};
pack.switchForceN = switchForceN;
pack.lowMethodKey = char(lowKey);
pack.highMethodKey = char(highKey);
pack.meta = meta;
pack.trajCacheLoaded = trajCacheLoaded;
pack.nTrajComputed = nTrajComputed;
pack.trajCell = trajCell;

end

function row = packQ9PerSampleRow(id, meta, alpha, o)
row = struct( ...
    "id", id, ...
    "switchForceN", meta.switchForceN, ...
    "lowKrMethodKey", meta.lowMethodKey, ...
    "highKrMethodKey", meta.highMethodKey, ...
    "alpha", alpha, ...
    "outcome", char(o.outcome), ...
    "yTrue", o.yTrue, ...
    "F_stop", o.F_stop, ...
    "t_stop", o.t_stop, ...
    "y_hat_at_stop", o.y_hat_at_stop, ...
    "nStepsToFirstKr", o.nStepsToFirstKr, ...
    "secToFirstKr", o.secToFirstKr, ...
    "stopErrorN", o.stopErrorN, ...
    "relativeStopError", o.relativeStopError, ...
    "lowLeakCategory", meta.lowLeakCategory, ...
    "highLeakCategory", meta.highLeakCategory, ...
    "label", meta.label);

end

function sampleOpts = buildQ9PiecewiseSampleOpts(isPercentYieldLow, isPercentYieldHigh, ...
    calibLow, calibHigh, yminCohortAbs, i, krVariant, policy)
sampleOpts = struct("krVariant", krVariant);
sampleOpts.minBandPointsForKr = policy.minBandPointsForKr;
sampleOpts.percentYieldBandGatePoints = policy.percentYieldBandGatePoints;
if isPercentYieldLow
    sampleOpts.calibALow = calibLow.a(i);
    sampleOpts.calibBLow = calibLow.b(i);
end
if isPercentYieldHigh
    sampleOpts.calibAHigh = calibHigh.a(i);
    sampleOpts.calibBHigh = calibHigh.b(i);
end
if isPercentYieldLow || isPercentYieldHigh
    sampleOpts.yminCohortAbs = yminCohortAbs;
end

end

function idx = q9TrajCacheLoadedSamples(trajCell, n)
idx = false(n, 1);
for i = 1:n
    if i <= numel(trajCell) && ~isempty(trajCell{i}) && isstruct(trajCell{i})
        idx(i) = true;
    end
end

end
