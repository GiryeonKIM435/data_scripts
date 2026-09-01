function report = prewarmDeployTrajectoryCache(cfg, opts, cohort, sampleCtx, fitCfg, methodOrder, calibByKey, prewarmOpts)
%prewarmDeployTrajectoryCache 方式別 kr 軌跡キャッシュを並列構築

if nargin < 7
    calibByKey = [];
end
if nargin < 8 || isempty(prewarmOpts)
    prewarmOpts = struct();
end
verboseProgress = true;
if isfield(prewarmOpts, "verboseProgress")
    verboseProgress = logical(prewarmOpts.verboseProgress);
end

if nargin < 6 || isempty(methodOrder)
    [methodOrder, ~] = resolveDeployMethodKeys(cfg, opts);
end

methods = KrMethodRegistry();
nMethods = numel(methodOrder);
ids = cohort.ids(:);
y = cohort.y(:);
nSamples = numel(ids);
if numel(y) ~= nSamples
    error("prewarmDeployTrajectoryCache:CohortSizeMismatch", ...
        "cohort.y (%d) と cohort.ids (%d) の長さが一致しません。", numel(y), nSamples);
end
if numel(sampleCtx) ~= nSamples
    error("prewarmDeployTrajectoryCache:SampleCtxSizeMismatch", ...
        "sampleCtx (%d) とコホート試料数 (%d) が一致しません。deploy_sample_contexts を再構築してください。", ...
        numel(sampleCtx), nSamples);
end
yminCohortAbs = computeCohortYieldMin(y);
krVariant = cfg.deploy.krVariant;
trajFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_traj"));
cacheDir = resolveDeployCacheDir(cfg, opts.analysisTag);

report = struct();
report.nMethods = nMethods;
report.trajSkipped = 0;
report.trajBuilt = 0;
report.elapsedSeconds = 0;

if ~isfield(opts, "forceRebuild")
    opts.forceRebuild = false;
end
reuseCache = cfg.cache.enabled && cfg.deploy.reuseCache && ~opts.forceRebuild;
saveCache = cfg.cache.enabled && cfg.deploy.saveTrajectoryCache;

needBuild = true(nMethods, 1);
if reuseCache
    for mi = 1:nMethods
        cached = loadMethodTrajectoryCache(cacheDir, methodOrder(mi), ids, trajFp);
        if cached.hit
            needBuild(mi) = false;
            report.trajSkipped = report.trajSkipped + 1;
        end
    end
end

totalBuild = nnz(needBuild);
if totalBuild == 0
    fprintf("beforeQ3 traj: 全 %d 方式キャッシュ済み（スキップ）\n", nMethods);
    return;
end

fprintf("beforeQ3 traj: %d/%d 方式を構築（%d 件スキップ）\n", ...
    totalBuild, nMethods, report.trajSkipped);
drawnow("limitrate");

poolInfo = ensurePaperStudyParallelPool(cfg);
useParallel = shouldUseMethodParallel(cfg, nMethods, "deploy");
parallelSamples = shouldUseSampleParallel(cfg, nMethods, "deploy");
tStart = tic;
buildIndices = find(needBuild);

if useParallel
    pool = gcp("nocreate");
    trajDir = fullfile(cacheDir, "traj");
    trajBaseline = countTrajCacheFiles(trajDir);
    tasks = repmat(struct("fn", [], "args", {{}}, "label", "", "nOut", 0), numel(buildIndices), 1);
    for bi = 1:numel(buildIndices)
        mi = buildIndices(bi);
        methodCalib = lookupDeployCalibForMethod(calibByKey, methodOrder(mi));
        assertPercentYieldCalibReady(methodOrder(mi), methods, methodCalib);
        tasks(bi).fn = @buildOneMethodTrajectory;
        tasks(bi).args = {methodOrder(mi), methods, sampleCtx, y, yminCohortAbs, ...
            ids, fitCfg, cacheDir, trajFp, saveCache, methodCalib, ...
            verboseProgress, krVariant, cfg, parallelSamples};
        tasks(bi).label = char(methodOrder(mi));
        tasks(bi).nOut = 0;
    end
    pollSec = 10;
    if totalBuild > 50
        pollSec = 15;
    end
    runParallelTaskBatch(pool, tasks, struct( ...
        "prefix", "Q3 prep traj", ...
        "pollSeconds", pollSec, ...
        "tStart", tStart, ...
        "completedProbe", struct("fn", @countTrajCacheFiles, "args", {{trajDir}}, "baseline", trajBaseline)));
else
    for bi = 1:numel(buildIndices)
        mi = buildIndices(bi);
        methodCalib = lookupDeployCalibForMethod(calibByKey, methodOrder(mi));
        assertPercentYieldCalibReady(methodOrder(mi), methods, methodCalib);
        buildOneMethodTrajectory(methodOrder(mi), methods, sampleCtx, y, yminCohortAbs, ...
            ids, fitCfg, cacheDir, trajFp, saveCache, methodCalib, ...
            verboseProgress, krVariant, cfg, parallelSamples);
        logStudyProgress("Q3 prep traj", bi, totalBuild, char(methodOrder(mi)), tStart);
    end
end

report.trajBuilt = totalBuild;
report.elapsedSeconds = toc(tStart);
fprintf("beforeQ3 traj: 完了 %d 方式 (%.0fs)\n", totalBuild, report.elapsedSeconds);
drawnow("limitrate");

end

function buildOneMethodTrajectory(methodKey, methods, sampleCtx, y, yminCohortAbs, ...
    ids, fitCfg, cacheDir, trajFp, saveCache, calib, ...
    verboseProgress, krVariant, cfg, parallelSamples)

if nargin < 12
    verboseProgress = false;
end
if nargin < 13 || isempty(krVariant)
    krVariant = "chord";
end
if nargin < 14
    cfg = [];
end
if nargin < 15
    parallelSamples = false;
end

mdef = lookupMethod(methodKey, methods);
n = numel(y);
isPercentYield = string(mdef.type) == "percent_yield";
if isPercentYield && ~isempty(calib) && ~isDeployCalibChordCompatible({calib}, n)
    error("prewarmDeployTrajectoryCache:CalibSizeMismatch", ...
        "percent_yield 方式 %s の calib 長 (%d) が試料数 (%d) と一致しません。", ...
        methodKey, numel(calib.a(:)), n);
end

useSampleParallel = parallelSamples && ~isempty(cfg);
progressLabel = "";
if verboseProgress
    progressLabel = sprintf("Q3 prep traj: %s", methodKey);
end
trajCell = buildMethodKrTrajectories(cfg, sampleCtx, y, mdef, fitCfg, calib, ...
    yminCohortAbs, krVariant, useSampleParallel, progressLabel);
if saveCache
    saveMethodTrajectoryCache(cacheDir, methodKey, ids, trajCell, trajFp);
end

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

function n = countTrajCacheFiles(trajDir)
n = 0;
if ~isfolder(trajDir)
    return;
end
d = dir(fullfile(trajDir, "*.mat"));
n = numel(d);
end

function calib = lookupDeployCalibForMethod(calibByKey, methodKey)
calib = [];
key = char(string(methodKey));
if isempty(calibByKey)
    return;
end
if isa(calibByKey, "containers.Map")
    if isKey(calibByKey, key)
        calib = calibByKey(key);
    end
    return;
end
if isstruct(calibByKey) && isfield(calibByKey, key)
    calib = calibByKey.(key);
end
end

function assertPercentYieldCalibReady(methodKey, methods, calib)
mdef = lookupMethod(methodKey, methods);
if string(mdef.type) ~= "percent_yield"
    return;
end
if isempty(calib) || ~isstruct(calib) || ~isfield(calib, "a") || ~isfield(calib, "b")
    error("prewarmDeployTrajectoryCache:MissingCalib", ...
        "percent_yield 方式 %s の calib がありません。ensureDeployCalibCache を先に実行してください。", ...
        methodKey);
end
end
