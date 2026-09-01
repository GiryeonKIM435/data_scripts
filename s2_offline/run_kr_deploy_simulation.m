function results = run_kr_deploy_simulation(cfg, opts)
%RUN_KR_DEPLOY_SIMULATION Q3: ストリーミング・チE�Eロイ�E�Efg.deploy.krVariant: chord / ls�E�E
if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "analysisTag")
    opts.analysisTag = "burgers_no_iqr";
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
end
if ~isfield(opts, "q1Results")
    opts.q1Results = [];
end

methods = KrMethodRegistry();
[methodKeys, methodPickMeta] = resolveDeployMethodKeys(cfg, opts);
methodOrder = orderMethodKeys(methodKeys, methods, cfg.deploy.runForceAbsFirst);
nMethods = numel(methodOrder);
if strcmpi(methodPickMeta.mode, "test")
    fprintf("Q3 test mode: %d methods (%s) [%s]\n", ...
        nMethods, strjoin(methodOrder, ", "), methodPickMeta.source);
else
    fprintf("Q3 full mode: %d methods\n", nMethods);
end
alphaValues = cfg.deploy.alphaValues(:);
nAlpha = numel(alphaValues);
timeOrder = cfg.deploy.timeOrder;
krVariant = cfg.deploy.krVariant;

if ~isempty(opts.q1Results) && isfield(opts.q1Results, "cohort") ...
        && opts.q1Results.useOutlierFilter == opts.useOutlierFilter
    cohort = opts.q1Results.cohort;
else
    cohort = loadStudyCohort(cfg, struct("useOutlierFilter", opts.useOutlierFilter));
end

y = cohort.y;
ids = cohort.ids;
tbl = cohort.predictorTable;
n = cohort.n;

outDir = fullfile(cfg.out.q3, opts.analysisTag);
if ~isfolder(outDir)
    mkdir(outDir);
end

cacheDir = resolveDeployCacheDir(cfg, opts.analysisTag);
cacheHits = struct("sampleCtx", false, "calib", false, "trajMethods", 0);

cohortTag = cohortCacheTag(cfg);
tPrep = tic;
sampleCtxFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_sample_ctx"));
sampleCache = loadDeploySampleContextCache(cfg, cohortTag, sampleCtxFp);
if sampleCache.hit
    sampleCtx = sampleCache.sampleCtx;
    if numel(sampleCtx) ~= n
        fprintf("Q3 prep [1/3] sampleCtx: キャチE��ュ試料数不一致 (%d vs %d) ↁE再構築\n", ...
            numel(sampleCtx), n);
        sampleCache.hit = false;
    else
        cacheHits.sampleCtx = true;
        fprintf("Q3 prep [1/3] sampleCtx: キャチE��ュヒッチE(%d 試斁E %.0fs)\n", n, toc(tPrep));
    end
end
if ~sampleCache.hit
    fprintf("Q3 prep [1/3] sampleCtx: 構築中 (%d 試斁E...\n", n);
    drawnow("limitrate");
    buildDeploySampleContextCache(cfg, cohort, struct( ...
        "analysisTag", cohortTag, "forceRebuild", true));
    sampleCache = loadDeploySampleContextCache(cfg, cohortTag, sampleCtxFp);
    if sampleCache.hit
        sampleCtx = sampleCache.sampleCtx;
        cacheHits.sampleCtx = true;
        fprintf("Q3 prep [1/3] sampleCtx: 構築完亁E(%.0fs)\n", toc(tPrep));
    else
        artifacts = loadDeployRawArtifacts(cfg);
        fitCfg = artifacts.fitCfg;
        sampleCtx = buildDeploySampleContexts(cfg, artifacts, ids, timeOrder, ...
            struct("progressPrefix", "Q3 prep sampleCtx"));
        fprintf("Q3 prep [1/3] sampleCtx: インライン構築完亁E(%.0fs)\n", toc(tPrep));
    end
end
drawnow("limitrate");

if ~exist("fitCfg", "var")
    artifacts = loadDeployRawArtifacts(cfg);
    fitCfg = artifacts.fitCfg;
end

tCalibPrep = tic;
calibFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_calib"));
calibCache = loadDeployCalibCache(cfg, cohortTag, calibFp, methodOrder, n);
calibByKey = containers.Map("KeyType", "char", "ValueType", "any");
if calibCache.hit
    cacheHits.calib = true;
    calibByKey = populateDeployCalibByKey(methodOrder, calibCache, n);
    fprintf("Q3 prep [2/3] calib: キャチE��ュヒッチE(%d 方弁E %.0fs)\n", ...
        numel(methodOrder), toc(tCalibPrep));
elseif ~isempty(opts.q1Results) && (~isempty(extractQ1DeployCalib(opts.q1Results)))
    q1Keys = opts.q1Results.methodKeys(:);
    q1Calib = extractQ1DeployCalib(opts.q1Results);
    if ~isDeployCalibChordCompatible(q1Calib, n)
        fprintf("Q3 prep [2/3] calib: Q1 結果の試料数不一致 ↁEmaster から再構築\n");
        calibOut = ensureDeployCalibCache(cfg, cohort, struct( ...
            "analysisTag", cohortTag, ...
            "q1Results", []));
        calibCache = loadDeployCalibCache(cfg, cohortTag, calibFp, methodOrder, n);
        if ~calibCache.hit && calibOut.hit
            calibCache.hit = true;
            calibCache.methodKeys = string(calibOut.methodKeys(:));
            calibCache.deployCalibChord = calibOut.deployCalibChord;
        end
        if calibCache.hit
            cacheHits.calib = true;
            calibByKey = populateDeployCalibByKey(methodOrder, calibCache, n);
            fprintf("Q3 prep [2/3] calib: 構築完亁E(source=%s, %.0fs)\n", ...
                calibOut.source, toc(tCalibPrep));
        end
    else
        for ci = 1:numel(q1Keys)
            calibByKey(char(q1Keys(ci))) = q1Calib{ci};
        end
        cacheHits.calib = true;
        fprintf("Q3 prep [2/3] calib: Q1 結果から読込 (%d 方弁E %.0fs)\n", ...
            numel(q1Keys), toc(tCalibPrep));
    end
else
    fprintf("Q3 prep [2/3] calib: 構築中 (%d 方弁E...\n", numel(cfg.krMethodKeys));
    drawnow("limitrate");
    calibOut = ensureDeployCalibCache(cfg, cohort, struct( ...
        "analysisTag", cohortTag, ...
        "q1Results", opts.q1Results));
    calibCache = loadDeployCalibCache(cfg, cohortTag, calibFp, methodOrder, n);
    if ~calibCache.hit && calibOut.hit
        calibCache.hit = true;
        calibCache.methodKeys = string(calibOut.methodKeys(:));
        calibCache.deployCalibChord = calibOut.deployCalibChord;
    end
    if calibCache.hit
        cacheHits.calib = true;
        calibByKey = populateDeployCalibByKey(methodOrder, calibCache, n);
        fprintf("Q3 prep [2/3] calib: 構築完亁E(source=%s, %.0fs)\n", ...
            calibOut.source, toc(tCalibPrep));
    else
        fprintf("Q3 prep [2/3] calib: 構築失敗（各方式�E評価時に LOO 校正を計算）\n");
    end
end
drawnow("limitrate");

calibByKey = ensurePercentYieldCalibForMethods(calibByKey, methodOrder, methods, cfg, cohort);

trajFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_traj"));
useParfor = shouldUseMethodParallel(cfg, nMethods, "deploy");
parallelSamples = shouldUseSampleParallel(cfg, nMethods, "deploy");
methodOptsCell = cell(nMethods, 1);
for mi = 1:nMethods
    key = char(methodOrder(mi));
    mo = struct();
    mo.trajectoryCacheDir = cacheDir;
    mo.trajFingerprint = trajFp;
    mo.saveTrajectoryCache = cfg.cache.enabled && cfg.deploy.saveTrajectoryCache;
    mo.krVariant = krVariant;
    if isKey(calibByKey, key)
        mo.calib = calibByKey(key);
    end
    mo.parallelSamples = parallelSamples;
    mo.cfg = cfg;
    methodOptsCell{mi} = mo;
end

methodMeta = cell(nMethods, 1);
krBatches = cell(nMethods, 1);
for mi = 1:nMethods
    key = methodOrder(mi);
    mdef = lookupMethod(key, methods);
    [leakCat, leakNote] = krLeakageCategory(key, mdef);
    krCol = resolveDeployKrColumn(tbl, key, krVariant);
    krBatches{mi} = tbl.(krCol);
    methodMeta{mi} = struct( ...
        "methodType", char(mdef.type), ...
        "gridStart", mdef.gridStart, ...
        "gridWidth", mdef.gridWidth, ...
        "gridValid", mdef.gridValid, ...
        "label", char(mdef.label), ...
        "leakCategory", char(leakCat), ...
        "leakNote", char(leakNote));
end

poolInfo = ensurePaperStudyParallelPool(cfg);

trajCacheReady = countTrajCacheHits(cacheDir, methodOrder, ids, trajFp, cfg);
if trajCacheReady < nMethods
    nTrajMiss = nMethods - trajCacheReady;
    fprintf("Q3 prep [3/3] traj: %d/%d 未キャチE��ュ ↁE評価前に一括構篁E(%d 方弁E...\n", ...
        nTrajMiss, nMethods, nTrajMiss);
    drawnow("limitrate");
    tTrajPrep = tic;
    trajBuildReport = prewarmDeployTrajectoryCache(cfg, opts, cohort, sampleCtx, fitCfg, ...
        methodOrder, calibByKey, struct("verboseProgress", true));
    trajCacheReady = countTrajCacheHits(cacheDir, methodOrder, ids, trajFp, cfg);
    fprintf("Q3 prep [3/3] traj: 構築完亁Ecache=%d/%d (built=%d, %.0fs, prep 合訁E%.0fs)\n", ...
        trajCacheReady, nMethods, trajBuildReport.trajBuilt, toc(tTrajPrep), toc(tPrep));
else
    fprintf("Q3 prep [3/3] traj cache %d/%d, workers=%d (prep 合訁E%.0fs)\n", ...
        trajCacheReady, nMethods, poolInfo.nWorkers, toc(tPrep));
end
drawnow("limitrate");

packs = cell(nMethods, 1);
tStart = tic;
fprintf("Q3 eval: %d methods 開姁E(parfor=%d, traj cache %d/%d)\n", ...
    nMethods, useParfor, trajCacheReady, nMethods);
drawnow("limitrate");

if useParfor
    pool = gcp("nocreate");
    tasks = repmat(struct("fn", [], "args", {{}}, "label", "", "nOut", 1), nMethods, 1);
    for mi = 1:nMethods
        tasks(mi).fn = @runStreamingDeployMethod;
        tasks(mi).args = {methodOrder(mi), methodMeta{mi}, krBatches{mi}, y, ids, ...
            sampleCtx, alphaValues, fitCfg, methodOptsCell{mi}};
        tasks(mi).label = char(methodOrder(mi));
        tasks(mi).nOut = 1;
    end
    pollSec = 5;
    if nMethods > 50
        pollSec = 10;
    end
    packResults = runParallelTaskBatch(pool, tasks, struct( ...
        "prefix", "Q3 eval", ...
        "pollSeconds", pollSec, ...
        "tStart", tStart));
    for mi = 1:nMethods
        packs{mi} = packResults{mi};
    end
else
    for mi = 1:nMethods
        packs{mi} = runStreamingDeployMethod( ...
            methodOrder(mi), methodMeta{mi}, krBatches{mi}, y, ids, ...
            sampleCtx, alphaValues, fitCfg, methodOptsCell{mi});
        logStudyProgress("Q3 eval", mi, nMethods, char(methodOrder(mi)), tStart);
    end
end

summaryRows = cell(nMethods * nAlpha, 25);
perSampleRows = cell(nMethods * nAlpha * n, 16);
summaryPtr = 0;
perPtr = 0;
methodResults = cell(nMethods, 1);

for mi = 1:nMethods
    pack = packs{mi};
    if isfield(pack, "trajCacheLoaded") && pack.trajCacheLoaded
        cacheHits.trajMethods = cacheHits.trajMethods + 1;
    end
    for ai = 1:nAlpha
        summaryPtr = summaryPtr + 1;
        summaryRows(summaryPtr, :) = pack.summaryRows(ai, :);
    end
    nRows = size(pack.perSampleRows, 1);
    perSampleRows(perPtr + (1:nRows), :) = pack.perSampleRows;
    perPtr = perPtr + nRows;
    methodResults{mi} = struct("calib", pack.calib, "foldOutcomes", pack.foldOutcomes);
end

elapsedTotal = toc(tStart);
fprintf("Q3 eval: 完亁E%.0fs\n", elapsedTotal);
drawnow("limitrate");
fprintf("Q3 post: 雁E���E保存中 ...\n");
drawnow("limitrate");

summaryTable = cell2table(summaryRows(1:summaryPtr, :), 'VariableNames', { ...
    'krMethodKey', 'alpha', 'methodType', 'gridStart', 'gridWidth', 'gridValid', ...
    'label', 'leakCategory', 'leakNote', 'nCohort', 'nUsed', ...
    'safeSuccessRate', 'safeStopRate', 'safeStopRate_sem', ...
    'fail_cross_warmup', 'fail_cross_after_pred', ...
    'fail_never_stopped', 'fail_no_kr', ...
    'stopMae_success', 'stopMae_success_sem', 'stopR2_success', ...
    'relativeStopError_success_mean', 'relativeStopError_success_sem', ...
    'warmupStepsMean', 'warmupSteps_sem'});
strCols = ["krMethodKey", "methodType", "label", "leakCategory", "leakNote"];
for si = 1:numel(strCols)
    c = strCols(si);
    if ismember(c, summaryTable.Properties.VariableNames)
        summaryTable.(c) = fillmissing(string(summaryTable.(c)), "constant", "");
    end
end

primaryAlpha = cfg.deploy.primaryAlpha;
primaryRows = summaryTable(summaryTable.alpha == primaryAlpha, :);
primaryRows = sortrows(primaryRows, "safeStopRate", "descend");
if ~isempty(primaryRows)
    bestKey = primaryRows.krMethodKey(1);
else
    bestKey = methodOrder(1);
end

perSampleTable = cell2table(perSampleRows(1:perPtr, :), 'VariableNames', { ...
    'id', 'krMethodKey', 'alpha', 'outcome', 'yTrue', 'F_stop', 't_stop', ...
    'y_hat_at_stop', 'F_lastUpdate', 'F_used', 'nStepsToFirstKr', 'secToFirstKr', ...
    'stopErrorN', 'relativeStopError', 'leakCategory', 'label'});

summaryTable = augmentStreamingDeploySummaryWithBootstrap(summaryTable, perSampleTable, 5000, cfg.cv.bootstrapSeed);
summaryTable = augmentStreamingDeploySummaryWithBootstrap(summaryTable, perSampleTable, 2000, cfg.cv.bootstrapSeed + 1);

writetable(summaryTable, fullfile(outDir, "streaming_deploy_summary.csv"));
writetable(perSampleTable, fullfile(outDir, "streaming_deploy_per_sample.csv"));

pairTable = compareStreamingDeployMethodsToBest(perSampleTable, summaryTable, alphaValues);
writetable(pairTable, fullfile(outDir, "streaming_deploy_vs_best_pairs.csv"));

bestByAlphaTable = selectBestDeployByAlpha(summaryTable, nan);
writetable(bestByAlphaTable, fullfile(outDir, "streaming_deploy_best_by_alpha.csv"));

fprintf("Q3 post: CSV 保存完亁En");

results = struct();
results.createdAt = datetime("now");
results.analysisTag = opts.analysisTag;
results.useOutlierFilter = opts.useOutlierFilter;
results.simulationType = "streaming_deploy";
results.krVariant = krVariant;
results.useParfor = useParfor;
results.pool = poolInfo;
results.elapsedSeconds = elapsedTotal;
results.cacheHits = cacheHits;
results.summaryTable = summaryTable;
results.perSampleTable = perSampleTable;
results.pairTable = pairTable;
results.bestMethodKey = char(bestKey);
results.primaryAlpha = primaryAlpha;
results.alphaValues = alphaValues;
results.methodKeys = methodOrder;
results.methodResults = methodResults;
results.cohort = cohort;
results.deployMode = methodPickMeta.mode;
results.deployMethodSource = methodPickMeta.source;
results.nMethodsTotal = numel(cfg.krMethodKeys);
results.nMethodsRun = nMethods;
results.bestByAlphaTable = bestByAlphaTable;

save(fullfile(outDir, "streaming_deploy_results.mat"), "results", "-v7");

if ~isempty(primaryRows)
    bestPrimary = primaryRows(1, :);
    fprintf("Q3 [%s]: best@alpha=%.1f=%s, safe-stop=%.1f%%, relErr=%.1f%%±%.1f%%, warmup=%.1f±%.1f steps\n", ...
        opts.analysisTag, primaryAlpha, bestKey, ...
        100 * bestPrimary.safeStopRate(1), ...
        100 * bestPrimary.relativeStopError_success_mean(1), ...
        100 * bestPrimary.relativeStopError_success_sem(1), ...
        bestPrimary.warmupStepsMean(1), bestPrimary.warmupSteps_sem(1));
end

if cfg.figures.enabled
    fprintf("Q3 figures: 生�E中 ...\n");
    tFig = tic;
    figOpts = struct();
    q1Summary = [];
    if isfield(opts, "q1Results") && isfield(opts.q1Results, "summaryTable")
        q1Summary = opts.q1Results.summaryTable;
        figOpts.q1SummaryTable = q1Summary;
    end
    if ~isempty(perSampleTable)
        summaryTable = augmentStreamingDeploySummaryWithStopR2(summaryTable, perSampleTable);
        results.summaryTable = summaryTable;
    end
    figOpts.globalMaeClim = computeGlobalMaeHeatmapClim(q1Summary, summaryTable, cfg);
    figOpts.globalRelErrorClim = computeGlobalRelErrorHeatmapClim(q1Summary, summaryTable, cfg);
    figOpts.globalStopR2Clim = computeGlobalStopR2HeatmapClim(summaryTable, cfg);
    figOpts.pairTable = pairTable;
    plotStreamingDeployFigures(summaryTable, alphaValues, outDir, cfg, figOpts);
    plotOnlineLoocvComboHeatmaps(summaryTable, alphaValues, outDir, cfg, struct( ...
        "figPrefix", "fig5", "q1SummaryTable", q1Summary, ...
        "globalMaeClim", figOpts.globalMaeClim, "pairTable", pairTable));
    plotBestDeployByAlphaFigures(bestByAlphaTable, outDir, cfg, struct( ...
        "figPrefix", "fig5e", "alphaValues", alphaValues));
    fprintf("Q3 figures: 完亁E(%.0fs)\n", toc(tFig));
end

if cfg.figures.enabled && strcmpi(methodPickMeta.mode, "test")
    fprintf("Q3 diagnostics: 失敗侁E時点可視化を生成中 ...\n");
    tDiag = tic;
    plotQ3TestDiagnostics(methodResults, methodOrder, methods, primaryAlpha, alphaValues, ...
        ids, y, sampleCtx, fitCfg, outDir, cfg);
    fprintf("Q3 diagnostics: 完亁E(%.0fs)\n", toc(tDiag));
end

fprintf("Q3 完亁E %.0fs (%s, kr=%s, parfor=%d, cache: ctx=%d calib=%d traj=%d/%d)\n", ...
    toc(tStart), opts.analysisTag, krVariant, useParfor, ...
    cacheHits.sampleCtx, cacheHits.calib, cacheHits.trajMethods, nMethods);

end

function calibByKey = populateDeployCalibByKey(methodOrder, calibCache, nSamples)
calibByKey = containers.Map("KeyType", "char", "ValueType", "any");
for mi = 1:numel(methodOrder)
    key = char(methodOrder(mi));
    idx = find(string(calibCache.methodKeys) == string(methodOrder(mi)), 1);
    if isempty(idx)
        continue;
    end
    calib = calibCache.deployCalibChord{idx};
    if nargin >= 3 && ~isempty(nSamples) && ~isDeployCalibChordCompatible({calib}, nSamples)
        continue;
    end
    calibByKey(key) = calib;
end
end

function calibByKey = ensurePercentYieldCalibForMethods(calibByKey, methodOrder, methods, cfg, cohort)
if isempty(calibByKey) || ~isa(calibByKey, "containers.Map")
    calibByKey = containers.Map("KeyType", "char", "ValueType", "any");
end
for mi = 1:numel(methodOrder)
    key = char(methodOrder(mi));
    mdef = lookupMethod(methodOrder(mi), methods);
    if string(mdef.type) ~= "percent_yield"
        continue;
    end
    needsCompute = true;
    if isKey(calibByKey, key)
        needsCompute = ~isDeployCalibChordCompatible({calibByKey(key)}, cohort.n);
    end
    if needsCompute
        calibByKey(key) = computeDeployCalibForMethod(cfg, cohort, methodOrder(mi));
    end
end
end

function order = orderMethodKeys(methodKeys, methods, forceAbsFirst)
if nargin < 3 || isempty(forceAbsFirst) || ~forceAbsFirst
    order = methodKeys(:);
    return;
end
priority = struct("force_abs", 1, "force_trailing", 2, "percent_yield", 3);
scores = 99 * ones(numel(methodKeys), 1);
for i = 1:numel(methodKeys)
    mdef = lookupMethod(methodKeys(i), methods);
    t = char(string(mdef.type));
    if isfield(priority, t)
        scores(i) = priority.(t);
    end
end
[~, ord] = sort(scores);
order = methodKeys(ord);
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

function tag = cohortCacheTag(cfg)
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
    tag = char(cfg.cache.cohortAnalysisTag);
else
    tag = "burgers_no_iqr";
end
end

function nHit = countTrajCacheHits(cacheDir, methodOrder, ids, trajFp, cfg)
nHit = 0;
if ~cfg.cache.enabled || ~cfg.deploy.reuseCache
    return;
end
for mi = 1:numel(methodOrder)
    cached = loadMethodTrajectoryCache(cacheDir, methodOrder(mi), ids, trajFp);
    if cached.hit
        nHit = nHit + 1;
    end
end
end

function plotQ3TestDiagnostics(methodResults, methodOrder, methods, primaryAlpha, alphaValues, ...
    ids, y, sampleCtx, fitCfg, outDir, cfg)

diagDir = fullfile(outDir, "diagnostics_testmode");
if ~isfolder(diagDir)
    mkdir(diagDir);
end

alphaIdx = find(abs(alphaValues - primaryAlpha) < 1e-9, 1);
if isempty(alphaIdx)
    alphaIdx = 1;
end
yminCohortAbs = computeCohortYieldMin(y);

for diagMethodIdx = 1:numel(methodOrder)
    methodKey = methodOrder(diagMethodIdx);
    mdef = lookupMethod(methodKey, methods);
    calib = methodResults{diagMethodIdx}.calib;
    outcomes = extractOutcomesAtAlpha(methodResults{diagMethodIdx}, alphaIdx);
    methodSlug = sanitizeMethodKey(methodKey);

    failIds = [];
    timelineIds = [];
    if isfield(cfg, "deploy")
        if isfield(cfg.deploy, "diagnosticFailSampleIds")
            failIds = cfg.deploy.diagnosticFailSampleIds;
        end
        if isfield(cfg.deploy, "diagnosticTimelineSampleIds")
            timelineIds = cfg.deploy.diagnosticTimelineSampleIds;
        end
    end

    failIdx = resolveDiagnosticSampleIndices(ids, failIds, ...
        @() pickFailSamples(outcomes, 5));
    failIdx = failIdx(1:min(5, numel(failIdx)));

    for k = 1:numel(failIdx)
        i = failIdx(k);
        diag = buildSampleDiagnosticMultiAlpha(i, outcomes(i), ids, y, sampleCtx, mdef, calib, ...
            fitCfg, alphaValues, yminCohortAbs, cfg.deploy.krVariant, cfg);
        outPath = fullfile(diagDir, sprintf("fail_case_%s_%02d_%s_id%03d.png", ...
            methodSlug, k, sanitizeOutcome(diag.outcome), diag.sampleId));
        plotDiagnosticCase(diag, outPath, cfg);
    end

    pickIdx = resolveDiagnosticSampleIndices(ids, timelineIds, ...
        @() pickTimelineSamples(outcomes));
    pickIdx = pickIdx(1:min(3, numel(pickIdx)));
    for k = 1:numel(pickIdx)
        i = pickIdx(k);
        diag = buildSampleDiagnosticMultiAlpha(i, outcomes(i), ids, y, sampleCtx, mdef, calib, ...
            fitCfg, alphaValues, yminCohortAbs, cfg.deploy.krVariant, cfg);
        outPath = fullfile(diagDir, sprintf("timeline_pick_%s_%02d_%s_id%03d.png", ...
            methodSlug, k, sanitizeOutcome(diag.outcome), diag.sampleId));
        plotDiagnosticCase(diag, outPath, cfg);
    end
end

end

function slug = sanitizeMethodKey(methodKey)
slug = char(strrep(string(methodKey), " ", "_"));
end

function diag = buildSampleDiagnosticMultiAlpha(i, outcome, ids, y, sampleCtx, mdef, calib, ...
    fitCfg, alphaValues, yminCohortAbs, krVariant, cfg)

ctx = sampleCtx{i};
yTrue = y(i);
sampleOpts = struct();
if nargin >= 11 && strlength(string(krVariant)) > 0
    sampleOpts.krVariant = char(string(krVariant));
end
policy = resolveStreamDeployPolicy(sampleOpts, cfg);
sampleOpts.minBandPointsForKr = policy.minBandPointsForKr;
sampleOpts.percentYieldBandGatePoints = policy.percentYieldBandGatePoints;
if string(mdef.type) == "percent_yield"
    sampleOpts.calibA = calib.a(i);
    sampleOpts.calibB = calib.b(i);
    sampleOpts.yminCohortAbs = yminCohortAbs;
end
krPath = streamDeployKrPath(ctx, yTrue, mdef, fitCfg, sampleOpts);
traj = applyDeployCalibToTrajectory(krPath, yTrue, calib.a(i), calib.b(i));

alphaValues = alphaValues(:);
tStopVec = nan(numel(alphaValues), 1);
for ai = 1:numel(alphaValues)
    stopOut = evalStopAlphas(traj, alphaValues(ai), yTrue);
    tStopVec(ai) = stopOut.t_stop;
end

forceOffsetN = 0;
if isfield(ctx, "forceOffsetN") && isfinite(ctx.forceOffsetN)
    forceOffsetN = ctx.forceOffsetN;
end
if isfield(traj, "forceAbs")
    forcePlot = traj.forceAbs(:);
else
    forcePlot = traj.force(:) + forceOffsetN;
end

diag = struct();
diag.sampleId = ids(i);
diag.alphaValues = alphaValues;
diag.methodKey = string(mdef.key);
diag.methodLabel = string(mdef.label);
diag.outcome = string(outcome.outcome);
diag.tStopVec = tStopVec;
diag.yTrue = yTrue;
diag.sec = ctx.sec(:);
diag.force = forcePlot;
diag.yHat = traj.yHat(:);
end

function idx = pickFailSamples(outcomes, nPick)
o = string({outcomes.outcome});
failIdx = find(startsWith(o, "fail_"));
if isempty(failIdx)
    failIdx = find(o ~= "success");
end
idx = failIdx(1:min(nPick, numel(failIdx)));
end

function idx = pickTimelineSamples(outcomes)
o = string({outcomes.outcome});
ok = find(o == "success", 1);
fc = find(startsWith(o, "fail_cross"), 1);
fn = find(o == "fail_never_stopped", 1);
idx = [ok, fc, fn];
idx = idx(isfinite(idx) & idx > 0);
if numel(idx) < 3
    extra = setdiff(1:numel(outcomes), idx, "stable");
    idx = [idx, extra(1:min(3 - numel(idx), numel(extra)))];
end
idx = idx(1:min(3, numel(idx)));
end

function plotDiagnosticCase(diag, outPath, cfg)
titleStr = sprintf("Sample %d | %s | outcome@\\alpha=%.1f=%s | %s", ...
    diag.sampleId, diag.methodLabel, cfg.deploy.primaryAlpha, diag.outcome, diag.methodKey);
plotQ3DeployForceTimeMultiAlphaFigure(diag.sec, diag.force, diag.yTrue, diag.yHat, ...
    diag.alphaValues, diag.tStopVec, titleStr, outPath, cfg);
end

function s = sanitizeOutcome(outcome)
s = char(strrep(string(outcome), " ", "_"));
end

function outcomes = extractOutcomesAtAlpha(methodResult, alphaIdx)
fo = methodResult.foldOutcomes;
if iscell(fo) && numel(fo) == 1 && iscell(fo{1})
    fo = fo{1};
end
if iscell(fo)
    useIdx = min(alphaIdx, numel(fo));
    if useIdx >= 1 && isstruct(fo{useIdx})
        outcomes = fo{useIdx};
        return;
    end
    if ~isempty(fo) && isstruct(fo{1})
        outcomes = fo{1};
        return;
    end
elseif isstruct(fo)
    outcomes = fo;
    return;
end
error("run_kr_deploy_simulation:BadFoldOutcomes", ...
    "foldOutcomes の形式を解釈できません。");
end
