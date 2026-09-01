function pack = runQ9SplitStreamingDeploy(cfg, offlineKey, onlineKey, calib, y, ids, sampleCtx, ...
    alphaValues, fitCfg, deployOpts)
%runQ9SplitStreamingDeploy OFFLINE 校正 + ONLINE kr の分離デプロイ

if nargin < 10 || isempty(deployOpts)
    deployOpts = struct();
end

methods = KrMethodRegistry();
onlineMdef = lookupKrMethodRegistry(onlineKey, methods);
offlineMdef = lookupKrMethodRegistry(offlineKey, methods);
n = numel(y);
nAlpha = numel(alphaValues);

yminCohortAbs = computeCohortYieldMin(y);
isPercentYield = string(onlineMdef.type) == "percent_yield";

policy = resolveStreamDeployPolicy(struct(), cfg);
onlineKrVariant = cfg.deploy.krVariant;
if isfield(cfg, "q9") && isfield(cfg.q9, "onlineKrVariant")
    onlineKrVariant = cfg.q9.onlineKrVariant;
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

[offlineLeakCat, offlineLeakNote] = krLeakageCategory(offlineKey, offlineMdef);
[onlineLeakCat, onlineLeakNote] = krLeakageCategory(onlineKey, onlineMdef);
meta = struct( ...
    "offlineMethodKey", char(offlineKey), ...
    "onlineMethodKey", char(onlineKey), ...
    "methodType", char(onlineMdef.type), ...
    "label", char(onlineMdef.label), ...
    "offlineLabel", char(offlineMdef.label), ...
    "offlineLeakCategory", char(offlineLeakCat), ...
    "offlineLeakNote", char(offlineLeakNote), ...
    "onlineLeakCategory", char(onlineLeakCat), ...
    "onlineLeakNote", char(onlineLeakNote));

trajCell = cell(n, 1);
trajCacheLoaded = false;
reuseCache = cfg.cache.enabled;
if isfield(cfg, "q9") && isfield(cfg.q9, "reuseCache")
    reuseCache = logical(cfg.q9.reuseCache);
end
if reuseCache && strlength(string(cacheDir)) > 0 && isfield(trajFingerprint, "hash")
    cached = loadQ9TrajectoryCache(cacheDir, onlineKey, ids, trajFingerprint);
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
            pool = gcp("nocreate");
            calibSub = struct("a", calib.a(needTrajIdx), "b", calib.b(needTrajIdx));
            built = buildMethodKrTrajectories(cfg, sampleCtx(needTrajIdx), y(needTrajIdx), ...
                onlineMdef, fitCfg, calibSub, yminCohortAbs, onlineKrVariant, ...
                true, sprintf("Q9 online %s", onlineKey));
            for ti = 1:numel(needTrajIdx)
                i = needTrajIdx(ti);
                trajCell{i} = built{ti};
                nTrajComputed = nTrajComputed + 1;
            end
        else
            for ti = 1:numel(needTrajIdx)
                i = needTrajIdx(ti);
                sampleOpts = buildQ9StreamSampleOpts(isPercentYield, calib, yminCohortAbs, i, ...
                    onlineKrVariant, policy);
                trajCell{i} = streamDeployKrPath(sampleCtx{i}, y(i), onlineMdef, fitCfg, sampleOpts);
                nTrajComputed = nTrajComputed + 1;
            end
        end
    else
        for ti = 1:numel(needTrajIdx)
            i = needTrajIdx(ti);
            sampleOpts = buildQ9StreamSampleOpts(isPercentYield, calib, yminCohortAbs, i, ...
                onlineKrVariant, policy);
            trajCell{i} = streamDeployKrPath(sampleCtx{i}, y(i), onlineMdef, fitCfg, sampleOpts);
            nTrajComputed = nTrajComputed + 1;
        end
    end
end

for i = 1:n
    if ~isfinite(calib.a(i)) || ~isfinite(calib.b(i))
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
        sampleOpts = buildQ9StreamSampleOpts(isPercentYield, calib, yminCohortAbs, i, ...
            onlineKrVariant, policy);
        krPath = streamDeployKrPath(sampleCtx{i}, y(i), onlineMdef, fitCfg, sampleOpts);
        trajCell{i} = krPath;
        nTrajComputed = nTrajComputed + 1;
    end

    traj = applyDeployCalibToTrajectory(krPath, y(i), calib.a(i), calib.b(i));
    for ai = 1:nAlpha
        o = evalStopAlphas(traj, alphaValues(ai), y(i));
        foldOutcomes{ai}(i) = o;
        rowPtr = rowPtr + 1;
        perSampleRows{rowPtr} = packQ9PerSampleRow(ids(i), meta, alphaValues(ai), o);
    end
end

if saveTrajectoryCache && strlength(string(cacheDir)) > 0 && isfield(trajFingerprint, "hash")
    saveQ9TrajectoryCache(cacheDir, onlineKey, ids, trajCell, trajFingerprint);
end

summaryRows = cell(nAlpha, 25);
for ai = 1:nAlpha
    alpha = alphaValues(ai);
    smeta = struct( ...
        "krMethodKey", sprintf("%s|%s", meta.offlineMethodKey, meta.onlineMethodKey), ...
        "alpha", alpha, "methodType", meta.methodType, ...
        "gridStart", onlineMdef.gridStart, "gridWidth", onlineMdef.gridWidth, ...
        "gridValid", onlineMdef.gridValid, "label", meta.label, ...
        "leakCategory", meta.onlineLeakCategory, "leakNote", meta.onlineLeakNote);
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
pack.calib = calib;
pack.foldOutcomes = {foldOutcomes};
pack.offlineMethodKey = char(offlineKey);
pack.onlineMethodKey = char(onlineKey);
pack.meta = meta;
pack.trajCacheLoaded = trajCacheLoaded;
pack.nTrajComputed = nTrajComputed;
pack.trajCell = trajCell;

end

function row = packQ9PerSampleRow(id, meta, alpha, o)
row = struct( ...
    "id", id, ...
    "offlineKrMethodKey", meta.offlineMethodKey, ...
    "onlineKrMethodKey", meta.onlineMethodKey, ...
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
    "offlineLeakCategory", meta.offlineLeakCategory, ...
    "onlineLeakCategory", meta.onlineLeakCategory, ...
    "label", meta.label);

end

function sampleOpts = buildQ9StreamSampleOpts(isPercentYield, calib, yminCohortAbs, i, krVariant, policy)
sampleOpts = struct("krVariant", krVariant);
sampleOpts.minBandPointsForKr = policy.minBandPointsForKr;
sampleOpts.percentYieldBandGatePoints = policy.percentYieldBandGatePoints;
if ~isPercentYield
    return;
end
sampleOpts.calibA = calib.a(i);
sampleOpts.calibB = calib.b(i);
sampleOpts.yminCohortAbs = yminCohortAbs;

end

function idx = q9TrajCacheLoadedSamples(trajCell, n)
idx = false(n, 1);
for i = 1:n
    if i <= numel(trajCell) && ~isempty(trajCell{i}) && isstruct(trajCell{i})
        idx(i) = true;
    end
end

end
