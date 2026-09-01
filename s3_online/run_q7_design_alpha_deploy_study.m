function results = run_q7_design_alpha_deploy_study(cfg, opts)
%RUN_Q7_DESIGN_ALPHA_DEPLOY_STUDY Q7: ???????????E?E????
%
% ??? ?_design=(1+ep)*gamma????E?E F>=yHat/alpha?E?Emin ???????E% force_abs / force_trailing ???Q3 traj / sampleCtx / calib ???E?????E???E% gammaValues ?????? analysisTag/gamma_XpY/ ????????????CSV??E??E
if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = cfg.q7.useOutlierFilter;
end
if isfield(cfg, "q7") && isfield(cfg.q7, "useYminStopClamp") && cfg.q7.useYminStopClamp
    warning("run_q7_design_alpha_deploy_study:YminClampUnused", ...
        "cfg.q7.useYminStopClamp=true ???????E??????E?? ymin ???E?????");
end

analysisTag = resolveQ7AnalysisTag(cfg, opts);
trajTag = resolveQ7TrajCacheTag(cfg, analysisTag, opts);
opts.analysisTag = trajTag;  % traj / fingerprint ? Q3 ???????E???E
cohort = loadStudyCohort(cfg, struct("useOutlierFilter", opts.useOutlierFilter));
y = cohort.y;
ids = cohort.ids;
tbl = cohort.predictorTable;
n = cohort.n;

methodOrder = resolveQ7MethodKeys(cfg);
nMethods = numel(methodOrder);
methods = KrMethodRegistry();
krVariant = cfg.deploy.krVariant;
designSlice = cfg.q7.designAlphaSlice;
gammaValues = resolveQ7GammaValues(cfg);

outDir = fullfile(cfg.out.q7, analysisTag);
if ~isfolder(outDir)
    mkdir(outDir);
end
cleanupQ7LegacyGridArtifacts(outDir);

gammaStr = strjoin(compose("%.2g", gammaValues(:)'), ", ");
fprintf("Q7: analysisTag=%s, trajTag=%s, methods=%d, kr=%s, p=%.2f, gamma=[%s]\n", ...
    analysisTag, trajTag, nMethods, krVariant, cfg.q7.quantileP, gammaStr);

%% ----- prep: sampleCtx / calib / traj?E?E3 ?????E????E?E-----
cohortTag = resolveCohortCacheTag(cfg);
cacheHits = struct("sampleCtx", false, "calib", false, "trajMethods", 0);
tPrep = tic;

sampleCtxFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_sample_ctx"));
sampleCache = loadDeploySampleContextCache(cfg, cohortTag, sampleCtxFp);
if sampleCache.hit && numel(sampleCache.sampleCtx) == n
    sampleCtx = sampleCache.sampleCtx;
    cacheHits.sampleCtx = true;
    fprintf("Q7 prep [1/3] sampleCtx: ???E??????E(%d)\n", n);
else
    fprintf("Q7 prep [1/3] sampleCtx: ???...\n");
    drawnow("limitrate");
    buildDeploySampleContextCache(cfg, cohort, struct( ...
        "analysisTag", cohortTag, "forceRebuild", true));
    sampleCache = loadDeploySampleContextCache(cfg, cohortTag, sampleCtxFp);
    if ~sampleCache.hit
        error("run_q7_design_alpha_deploy_study:SampleCtx", "sampleCtx ??????????");
    end
    sampleCtx = sampleCache.sampleCtx;
    cacheHits.sampleCtx = true;
end

artifacts = loadDeployRawArtifacts(cfg);
fitCfg = artifacts.fitCfg;

methodMeta = cell(nMethods, 1);
krBatches = cell(nMethods, 1);
for mi = 1:nMethods
    key = methodOrder(mi);
    mdef = lookupKrMethodRegistry(key, methods);
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

calibFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_calib"));
calibCache = loadDeployCalibCache(cfg, cohortTag, calibFp, methodOrder, n);
calibByKey = containers.Map("KeyType", "char", "ValueType", "any");
if calibCache.hit
    calibByKey = populateDeployCalibByKey(methodOrder, calibCache, n);
    cacheHits.calib = true;
    fprintf("Q7 prep [2/3] calib: ???E??????En");
end
missingCalib = false(nMethods, 1);
for mi = 1:nMethods
    key = char(methodOrder(mi));
    if ~isKey(calibByKey, key) || ~isDeployCalibChordCompatible({calibByKey(key)}, n)
        missingCalib(mi) = true;
    end
end
if any(missingCalib)
    fprintf("Q7 prep [2/3] calib: ?? %d ??? LOO ??E..\n", nnz(missingCalib));
    drawnow("limitrate");
    for mi = find(missingCalib)'
        key = char(methodOrder(mi));
        calibByKey(key) = fitDeployCalibLoocv(krBatches{mi}, y);
    end
    cacheHits.calib = cacheHits.calib && ~any(missingCalib);
elseif ~cacheHits.calib
    cacheHits.calib = true;
    fprintf("Q7 prep [2/3] calib: ??En");
end

trajCacheDir = resolveDeployCacheDir(cfg, trajTag);
trajFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_traj"));
trajCacheReady = countQ7TrajCacheHits(trajCacheDir, methodOrder, ids, trajFp, cfg);
if trajCacheReady < nMethods
    fprintf("Q7 prep [3/3] traj: %d/%d ??????? ?E???E?? prewarm...\n", ...
        trajCacheReady, nMethods);
    drawnow("limitrate");
    missing = strings(0, 1);
    for mi = 1:nMethods
        probed = loadQ7MethodTrajectoryCache(trajCacheDir, methodOrder(mi), ids, trajFp);
        if ~probed.hit
            missing(end + 1, 1) = string(methodOrder(mi)); %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        fprintf("Q7 prep [3/3] traj: ?????E %d ?????E(method-parallel)...\n", numel(missing));
        cfgTraj = cfg;
        cfgTraj.q7.saveTrajectoryCache = true;
        % ?????? Q3 ???? method-parallel ? prewarm ???
        prewarmDeployTrajectoryCache(cfgTraj, opts, cohort, sampleCtx, fitCfg, ...
            missing, calibByKey, struct("verboseProgress", true));
        trajFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_traj"));
    end
    trajCacheReady = countQ7TrajCacheHits(trajCacheDir, methodOrder, ids, trajFp, cfg);
else
    fprintf("Q7 prep [3/3] traj: ?????E?????E?? (%d/%d, sampleIds ??E\n", ...
        trajCacheReady, nMethods);
end
fprintf("Q7 prep [3/3] traj cache %d/%d (prep %.0fs)\n", trajCacheReady, nMethods, toc(tPrep));
cacheHits.trajMethods = trajCacheReady;
ensurePaperStudyParallelPool(cfg);

%% ----- gamma ????E-----
nGamma = numel(gammaValues);
byGamma = cell(nGamma, 1);
compareBestParts = cell(nGamma, 1);

for gi = 1:nGamma
    gamma = gammaValues(gi);
    gTag = formatQ7GammaTag(gamma);
    outDirGamma = fullfile(outDir, gTag);
    if ~isfolder(outDirGamma)
        mkdir(outDirGamma);
    end

    fprintf("=== Q7 gamma=%.3g (%d/%d) ?E%s ===\n", gamma, gi, nGamma, gTag);
    cfgLoop = cfg;
    cfgLoop.q7.gamma = gamma;

    fprintf("Q7 design: training-cohort ep ?Efold-specific alpha_design (gamma=%.3g)...\n", gamma);
    [designTable, alphaByMethod, alphaPerSample] = computeQ7DesignAlphaTable( ...
        cfgLoop, cohort, methodOrder, calibByKey, outDirGamma);
    alphaByMethod(~isfinite(alphaByMethod) | alphaByMethod <= 0) = nan;
    if all(~isfinite(alphaByMethod(:)))
        error("run_q7_design_alpha_deploy_study:BadAlphaDesign", ...
            "??? fold ? alphaDesign ?????? (gamma=%.3g)?", gamma);
    end

    progressPrefix = sprintf("Q7 design eval g=%.3g", gamma);
    [designSummaryRaw, designPerSampleRaw] = runQ7MethodDeployBatch(cfgLoop, cohort, ...
        methodOrder, methodMeta, krBatches, sampleCtx, fitCfg, calibByKey, ...
        alphaByMethod, trajCacheDir, trajFp, progressPrefix);

    designPerSample = designPerSampleRaw;
    designPerSample.alphaDesign = designPerSample.alpha;
    designSummary = designSummaryRaw;
    designSummary.alphaDesign = designSummary.alpha;
    % Design-? ?????? fold ?? ? ? alphaDesign ????
    % ?????????????????? alpha ?? designSlice ?????
    designPerSample.alpha = designSlice * ones(height(designPerSample), 1);
    designSummary.alpha = designSlice * ones(height(designSummary), 1);

    designSummary = joinQ7DesignMeta(designSummary, designTable);
    [designPerSample, designSummary] = augmentQ7OnlineSafetyMetrics(designPerSample, designSummary);
    designSummary = augmentStreamingDeploySummaryWithBootstrap(designSummary, designPerSample, 5000, cfg.cv.bootstrapSeed);
    designSummary = augmentStreamingDeploySummaryWithBootstrap(designSummary, designPerSample, 2000, cfg.cv.bootstrapSeed + 1);
    designSummary = augmentStreamingDeploySummaryWithStopR2(designSummary, designPerSample);

    writetable(designSummary, fullfile(outDirGamma, "q7_design_deploy_summary.csv"));
    writetable(designPerSample, fullfile(outDirGamma, "q7_design_deploy_per_sample.csv"));

    designBest = selectQ7DesignBestByScope(designSummary, struct( ...
        "bestSelectionMode", cfgLoop.q7.bestSelectionMode));
    writetable(designBest, fullfile(outDirGamma, "q7_design_best_by_scope.csv"));

    designPair = compareStreamingDeployMethodsToBest(designPerSample, designSummary, designSlice);
    writetable(designPair, fullfile(outDirGamma, "q7_design_vs_best_pairs.csv"));

    cfgFig = cfgLoop;
    cfgFig.krMethodKeys = methodOrder;
    if cfg.figures.enabled
        fprintf("Q7 figures (gamma=%.3g): ??E?...\n", gamma);
        tFig = tic;
        figOpts = struct();
        figOpts.q1SummaryTable = loadQ1SummaryTable(cfg);
        figOpts.globalMaeClim = computeGlobalMaeHeatmapClim(figOpts.q1SummaryTable, designSummary, cfg);
        figOpts.globalRelErrorClim = computeGlobalRelErrorHeatmapClim(figOpts.q1SummaryTable, designSummary, cfg);
        figOpts.globalStopR2Clim = computeGlobalStopR2HeatmapClim(designSummary, cfg);
        figOpts.pairTable = designPair;
        figOpts.figPrefix = "fig7";
        figOpts.cleanupLegacy = false;
        figOpts.allowedMetricNames = [ ...
            "safe_stop_rate"
            "stop_mae"
            "rel_stop_error"
            "stop_r2"];
        plotStreamingDeployFigures(designSummary, designSlice, outDirGamma, cfgFig, figOpts);
        plotQ7DesignAlphaFigures(designSummary, designTable, outDirGamma, cfgFig);
        fprintf("Q7 figures (gamma=%.3g): ??E(%.0fs)\n", gamma, toc(tFig));
    end

    pack = struct();
    pack.gamma = gamma;
    pack.gammaTag = gTag;
    pack.outDir = outDirGamma;
    pack.designTable = designTable;
    pack.alphaPerSample = alphaPerSample;
    pack.designSummary = designSummary;
    pack.designPerSample = designPerSample;
    pack.designBest = designBest;
    pack.designPair = designPair;
    byGamma{gi} = pack;

    if ~isempty(designBest)
        bestCompare = designBest;
        bestCompare.gamma = gamma * ones(height(bestCompare), 1);
        bestCompare.gammaTag = repmat(string(gTag), height(bestCompare), 1);
        compareBestParts{gi} = bestCompare;

        rowAbs = designBest(string(designBest.scope) == "force_abs", :);
        if ~isempty(rowAbs) && strlength(string(rowAbs.krMethodKey(1))) > 0
            fprintf("Q7 design best force_abs (gamma=%.3g): %s (?_design=%.3f, SSR=%.1f%%, Final-update MAE=%.2f N, fail=%d)\n", ...
                gamma, char(rowAbs.krMethodKey(1)), rowAbs.alphaDesign(1), ...
                100 * rowAbs.safeStopRate(1), rowAbs.finalUpdateMae(1), rowAbs.nSafeStopFail(1));
        end
    end

    gammaResults = pack; %#ok<NASGU>
    save(fullfile(outDirGamma, "q7_design_alpha_deploy_results.mat"), "gammaResults", "-v7");
end

compareBest = table();
for gi = 1:nGamma
    if ~isempty(compareBestParts{gi})
        compareBest = [compareBest; compareBestParts{gi}]; %#ok<AGROW>
    end
end
if ~isempty(compareBest)
    writetable(compareBest, fullfile(outDir, "q7_gamma_compare_best_by_scope.csv"));
end

%% ----- results?E???E??E??E-----
results = struct();
results.createdAt = datetime("now");
results.analysisTag = analysisTag;
results.trajTag = trajTag;
results.useOutlierFilter = opts.useOutlierFilter;
results.krVariant = krVariant;
results.quantileP = cfg.q7.quantileP;
results.gammaValues = gammaValues(:);
results.gamma = gammaValues(1);
results.designAlphaSlice = designSlice;
results.methodKeys = methodOrder;
results.cacheHits = cacheHits;
results.byGamma = byGamma;
results.compareBest = compareBest;
results.cohort = cohort;
results.useYminStopClamp = cfg.q7.useYminStopClamp;
% ????: ?? gamma ???????????????
if nGamma >= 1 && ~isempty(byGamma{1})
    results.designTable = byGamma{1}.designTable;
    results.designSummary = byGamma{1}.designSummary;
    results.designPerSample = byGamma{1}.designPerSample;
    results.designBest = byGamma{1}.designBest;
end

save(fullfile(outDir, "q7_design_alpha_deploy_results.mat"), "results", "-v7");
fprintf("Q7 ??E %s (gamma=[%s])\n", outDir, gammaStr);
end

function gammaValues = resolveQ7GammaValues(cfg)
if isfield(cfg, "q7") && isfield(cfg.q7, "gammaValues") && ~isempty(cfg.q7.gammaValues)
    gammaValues = double(cfg.q7.gammaValues(:));
elseif isfield(cfg, "q7") && isfield(cfg.q7, "gamma") && isfinite(cfg.q7.gamma)
    gammaValues = double(cfg.q7.gamma);
else
    gammaValues = 1;
end
gammaValues = gammaValues(isfinite(gammaValues) & gammaValues > 0);
if isempty(gammaValues)
    error("run_q7_design_alpha_deploy_study:BadGamma", "??? gammaValues ???????");
end
end

function tag = formatQ7GammaTag(gamma)
tag = "gamma_" + strrep(sprintf("%.1f", gamma), ".", "p");
end

function tag = resolveCohortCacheTag(cfg)
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
    tag = char(cfg.cache.cohortAnalysisTag);
else
    tag = "burgers_no_iqr";
end
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

function nHit = countQ7TrajCacheHits(cacheDir, methodOrder, ids, trajFp, cfg)
nHit = 0;
reuse = cfg.cache.enabled && cfg.q7.reuseCache;
if ~reuse
    return;
end
for mi = 1:numel(methodOrder)
    cached = loadQ7MethodTrajectoryCache(cacheDir, methodOrder(mi), ids, trajFp);
    if cached.hit
        nHit = nHit + 1;
    end
end
end

function summary = joinQ7DesignMeta(summary, designTable)
summary.feasible = false(height(summary), 1);
summary.ep = nan(height(summary), 1);
summary.bandHighWeff = nan(height(summary), 1);
summary.feasibilityMargin = nan(height(summary), 1);
summary.ymin = nan(height(summary), 1);
for i = 1:height(summary)
    idx = find(string(designTable.krMethodKey) == string(summary.krMethodKey(i)), 1);
    if isempty(idx)
        continue;
    end
    summary.feasible(i) = logical(designTable.feasible(idx));
    summary.ep(i) = designTable.ep(idx);
    summary.bandHighWeff(i) = designTable.bandHighWeff(idx);
    summary.feasibilityMargin(i) = designTable.feasibilityMargin(idx);
    summary.ymin(i) = designTable.ymin(idx);
    if ~ismember("alphaDesign", summary.Properties.VariableNames) ...
            || ~isfinite(summary.alphaDesign(i))
        summary.alphaDesign(i) = designTable.alphaDesign(idx);
    end
end
end

function cleanupQ7LegacyGridArtifacts(outDir)
%cleanupQ7LegacyGridArtifacts ? Grid / ????E? Design ??????

if ~isfolder(outDir)
    return;
end

legacyCsv = [ ...
    "streaming_deploy_summary.csv"
    "streaming_deploy_per_sample.csv"
    "streaming_deploy_vs_best_pairs.csv"
    "streaming_deploy_best_by_alpha.csv"
    "q7_design_alpha_by_method.csv"
    "q7_design_deploy_summary.csv"
    "q7_design_deploy_per_sample.csv"
    "q7_design_best_by_scope.csv"
    "q7_design_vs_best_pairs.csv"];
nDeleted = 0;
for i = 1:numel(legacyCsv)
    fpath = fullfile(outDir, legacyCsv(i));
    if isfile(fpath)
        delete(fpath);
        nDeleted = nDeleted + 1;
    end
end

patterns = [ ...
    "fig7*.*"
    "fig7g*.*"
    "fig7x*.*"
    "fig7*_a15.*"
    "fig7*_a20.*"
    "fig7*_a30.*"
    "fig7e_best_stoperr_by_alpha.*"
    "fig7d*"];
for pi = 1:numel(patterns)
    hits = dir(fullfile(outDir, patterns(pi)));
    for hi = 1:numel(hits)
        if hits(hi).isdir
            continue;
        end
        delete(fullfile(outDir, hits(hi).name));
        nDeleted = nDeleted + 1;
    end
end
if nDeleted > 0
    fprintf("Q7 cleanup: ? Grid/???EDesign ??? %d ????\n", nDeleted);
end
end
