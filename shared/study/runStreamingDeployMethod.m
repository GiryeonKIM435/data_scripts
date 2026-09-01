function pack = runStreamingDeployMethod(methodKey, meta, krBatch, y, ids, sampleCtx, alphaValues, fitCfg, methodOpts)
%runStreamingDeployMethod 1 方式分のストリーミング・デプロイ（parfor 用）

if nargin < 9 || isempty(methodOpts)
    methodOpts = struct();
end

skipEval = isfield(methodOpts, "skipEval") && methodOpts.skipEval;
parallelSamples = isfield(methodOpts, "parallelSamples") && methodOpts.parallelSamples;
cfgLocal = [];
if isfield(methodOpts, "cfg") && ~isempty(methodOpts.cfg)
    cfgLocal = methodOpts.cfg;
end

methods = KrMethodRegistry();
mdef = lookupMethod(methodKey, methods);
n = numel(y);
alphaValues = double(alphaValues(:));
perSampleAlpha = isfield(methodOpts, "perSampleAlpha") && methodOpts.perSampleAlpha;
if ~perSampleAlpha && numel(alphaValues) == n && n > 10
    % nMethods×nSamples 経路からの fold 別 alpha
    perSampleAlpha = true;
end
if perSampleAlpha
    if numel(alphaValues) ~= n
        error("runStreamingDeployMethod:BadPerSampleAlpha", ...
            "per-sample alpha は試料数 (%d) と一致する必要があります。", n);
    end
    nAlpha = 1;
else
    nAlpha = numel(alphaValues);
end

yminCohortAbs = computeCohortYieldMin(y);
isPercentYield = string(mdef.type) == "percent_yield";

policy = resolveStreamDeployPolicy(struct(), cfgLocal);

krVariant = "chord";
if isfield(methodOpts, "krVariant") && strlength(string(methodOpts.krVariant)) > 0
    krVariant = char(string(methodOpts.krVariant));
end

if isfield(methodOpts, "calib") && ~isempty(methodOpts.calib)
    calib = methodOpts.calib;
else
    calib = fitDeployCalibLoocv(krBatch, y);
end

trajFingerprint = struct();
if isfield(methodOpts, "trajFingerprint")
    trajFingerprint = methodOpts.trajFingerprint;
end
cacheDir = "";
if isfield(methodOpts, "trajectoryCacheDir")
    cacheDir = char(methodOpts.trajectoryCacheDir);
end
saveTrajectoryCache = isfield(methodOpts, "saveTrajectoryCache") && methodOpts.saveTrajectoryCache;

trajCell = cell(n, 1);
trajCacheLoaded = false;
if strlength(string(cacheDir)) > 0 && isfield(trajFingerprint, "hash")
    cached = loadMethodTrajectoryCache(cacheDir, methodKey, ids, trajFingerprint);
    if cached.hit
        trajCell = cached.trajectories;
        trajCacheLoaded = true;
    end
end

foldOutcomes = cell(nAlpha, 1);
perSampleRows = cell(n * nAlpha, 21);
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

needTrajIdx = find(~trajCacheLoadedSamples(trajCell, n));
if ~isempty(needTrajIdx)
    if parallelSamples && ~isempty(cfgLocal)
        calibSub = struct("a", calib.a(needTrajIdx), "b", calib.b(needTrajIdx));
        built = buildMethodKrTrajectories(cfgLocal, sampleCtx(needTrajIdx), y(needTrajIdx), ...
            mdef, fitCfg, calibSub, yminCohortAbs, krVariant, ...
            true, sprintf("Q3 sample traj %s", methodKey));
        for ti = 1:numel(needTrajIdx)
            i = needTrajIdx(ti);
            trajCell{i} = built{ti};
            nTrajComputed = nTrajComputed + 1;
        end
    else
        for ti = 1:numel(needTrajIdx)
            i = needTrajIdx(ti);
            sampleOpts = buildStreamSampleOpts(isPercentYield, calib, yminCohortAbs, i, krVariant, policy);
            krPath = streamDeployKrPath(sampleCtx{i}, y(i), mdef, fitCfg, sampleOpts);
            trajCell{i} = krPath;
            nTrajComputed = nTrajComputed + 1;
        end
    end
end

if skipEval
    pack = struct();
    pack.summaryRows = cell(nAlpha, 24);
    pack.perSampleRows = cell(0, 21);
    pack.calib = calib;
    pack.foldOutcomes = {cell(nAlpha, 1)};
    pack.methodKey = char(methodKey);
    pack.trajCacheLoaded = trajCacheLoaded;
    pack.nTrajComputed = nTrajComputed;
    return;
end

for i = 1:n
    if ~isfinite(calib.a(i)) || ~isfinite(calib.b(i))
        for ai = 1:nAlpha
            o = emptyOutcome;
            o.outcome = "fail_no_kr";
            o.yTrue = y(i);
            if perSampleAlpha
                o.alpha = alphaValues(i);
            else
                o.alpha = alphaValues(ai);
            end
            foldOutcomes{ai}(i) = o;
            rowPtr = rowPtr + 1;
            if perSampleAlpha
                perSampleRows(rowPtr, :) = packPerSampleRow(ids(i), methodKey, alphaValues(i), o, meta);
            else
                perSampleRows(rowPtr, :) = packPerSampleRow(ids(i), methodKey, alphaValues(ai), o, meta);
            end
        end
        continue;
    end

    if i <= numel(trajCell) && ~isempty(trajCell{i}) && isstruct(trajCell{i})
        krPath = trajCell{i};
    else
        sampleOpts = buildStreamSampleOpts(isPercentYield, calib, yminCohortAbs, i, krVariant, policy);
        krPath = streamDeployKrPath(sampleCtx{i}, y(i), mdef, fitCfg, sampleOpts);
        trajCell{i} = krPath;
        nTrajComputed = nTrajComputed + 1;
    end

    traj = applyDeployCalibToTrajectory(krPath, y(i), calib.a(i), calib.b(i));
    if perSampleAlpha
        o = evalStopAlphas(traj, alphaValues(i), y(i));
        foldOutcomes{1}(i) = o;
        rowPtr = rowPtr + 1;
        perSampleRows(rowPtr, :) = packPerSampleRow(ids(i), methodKey, alphaValues(i), o, meta);
    else
        for ai = 1:nAlpha
            o = evalStopAlphas(traj, alphaValues(ai), y(i));
            foldOutcomes{ai}(i) = o;
            rowPtr = rowPtr + 1;
            perSampleRows(rowPtr, :) = packPerSampleRow(ids(i), methodKey, alphaValues(ai), o, meta);
        end
    end
end

if saveTrajectoryCache && strlength(string(cacheDir)) > 0 && isfield(trajFingerprint, "hash")
    saveMethodTrajectoryCache(cacheDir, methodKey, ids, trajCell, trajFingerprint);
end

summaryRows = cell(nAlpha, 33);
for ai = 1:nAlpha
    if perSampleAlpha
        alphaFinite = alphaValues(isfinite(alphaValues) & alphaValues > 0);
        if isempty(alphaFinite)
            alpha = nan;
        else
            alpha = median(alphaFinite, "omitnan");
        end
    else
        alpha = alphaValues(ai);
    end
    smeta = struct( ...
        "krMethodKey", char(methodKey), "alpha", alpha, "methodType", meta.methodType, ...
        "gridStart", meta.gridStart, "gridWidth", meta.gridWidth, ...
        "gridValid", meta.gridValid, "label", meta.label, ...
        "leakCategory", meta.leakCategory, "leakNote", meta.leakNote);
    srow = summarizeStreamingDeployOutcomes(foldOutcomes{ai}, smeta);
    summaryRows(ai, :) = {srow.krMethodKey, srow.alpha, srow.methodType, ...
        srow.gridStart, srow.gridWidth, srow.gridValid, srow.label, ...
        srow.leakCategory, srow.leakNote, srow.nCohort, srow.nUsed, ...
        srow.safeSuccessRate, srow.safeStopRate, srow.safeStopRate_sem, srow.nSafeStopFail, ...
        srow.fail_cross_warmup, srow.fail_cross_after_pred, ...
        srow.fail_never_stopped, srow.fail_no_kr, ...
        srow.nEvaluated, srow.nNoPrediction, ...
        srow.finalUpdateMae, srow.finalUpdateMae_sem, srow.finalUpdateR2, ...
        srow.relativeFinalUpdateError_mean, srow.relativeFinalUpdateError_sem, ...
        srow.stopMae_success, srow.stopMae_success_sem, srow.stopR2_success, ...
        srow.relativeStopError_success_mean, srow.relativeStopError_success_sem, ...
        srow.warmupStepsMean, srow.warmupSteps_sem};
end

pack = struct();
pack.summaryRows = summaryRows;
pack.perSampleRows = perSampleRows(1:rowPtr, :);
pack.calib = calib;
pack.foldOutcomes = {foldOutcomes};
pack.methodKey = char(methodKey);
pack.trajCacheLoaded = trajCacheLoaded;
pack.nTrajComputed = nTrajComputed;

end

function row = packPerSampleRow(id, methodKey, alpha, o, meta)
row = {id, char(methodKey), alpha, char(o.outcome), o.yTrue, o.F_stop, o.t_stop, ...
    o.y_hat_at_stop, o.F_lastUpdate, o.F_used, o.nStepsToFirstKr, o.secToFirstKr, ...
    o.stopErrorN, o.relativeStopError, ...
    o.t_finalUpdate, o.F_finalUpdate, o.y_hat_finalUpdate, ...
    o.finalUpdateErrorN, o.relativeFinalUpdateError, ...
    meta.leakCategory, meta.label};
end

function sampleOpts = buildStreamSampleOpts(isPercentYield, calib, yminCohortAbs, i, krVariant, policy)
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

function m = lookupMethod(key, methods)
m = methods(1);
for i = 1:numel(methods)
    if string(methods(i).key) == string(key)
        m = methods(i);
        return;
    end
end
end

function idx = trajCacheLoadedSamples(trajCell, n)
idx = false(n, 1);
for i = 1:n
    if i <= numel(trajCell) && ~isempty(trajCell{i}) && isstruct(trajCell{i})
        idx(i) = true;
    end
end
end
