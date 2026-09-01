function results = run_kr_method_benchmark(cfg, opts)
%RUN_KR_METHOD_BENCHMARK Q1: kr 方式別 LOOCV ベンチ�Eーク

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "analysisTag")
    opts.analysisTag = "burgers_iqr2";
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
end
if ~isfield(opts, "commonCaseOnly")
    opts.commonCaseOnly = false;
end

methods = KrMethodRegistry();
methodKeys = cfg.krMethodKeys(:);
nMethods = numel(methodKeys);
variants = resolveQ1KrVariants(cfg);
nVariants = numel(variants);
deployKrVariant = string(cfg.deploy.krVariant);

cohortOpts = struct("useOutlierFilter", opts.useOutlierFilter);
if opts.commonCaseOnly
    cohortOpts.requireKrKeys = methodKeys;
end
cohort = loadStudyCohort(cfg, cohortOpts);

outDir = fullfile(cfg.out.q1, opts.analysisTag);
if opts.commonCaseOnly
    outDir = fullfile(outDir, "common_case");
end
if ~isfolder(outDir)
    mkdir(outDir);
end

skr = load(cfg.paths.krTable, "krExport");
krExport = skr.krExport;

y = cohort.y;
tbl = cohort.predictorTable;
colNames = string(tbl.Properties.VariableNames);

rows = cell(nMethods * nVariants, 19);
cvResults = cell(nMethods, nVariants);
deployCalib = cell(nMethods, 1);

krBatchCell = cell(nMethods, 1);
methodMetaCell = cell(nMethods, 1);
nSuccessVec = nan(nMethods, 1);

for mi = 1:nMethods
    key = methodKeys(mi);
    mdef = lookupMethod(key, methods);
    [leakCat, leakNote] = krLeakageCategory(key, mdef);
    nSuccessVec(mi) = countKrSuccess(krExport, key, cohort.idsComplete);

    batches = cell(nVariants, 1);
    for vi = 1:nVariants
        krCol = resolveDeployKrColumn(tbl, key, variants(vi));
        if ~ismember(krCol, colNames)
            error("run_kr_method_benchmark:MissingKrCol", ...
                "predictorTable に列がありません: %s（master の再構築が必要です）", krCol);
        end
        batches{vi} = tbl.(krCol);
    end
    krBatchCell{mi} = batches;
    methodMetaCell{mi} = struct( ...
        "methodType", char(mdef.type), ...
        "gridStart", mdef.gridStart, ...
        "gridWidth", mdef.gridWidth, ...
        "gridValid", mdef.gridValid, ...
        "label", char(mdef.label), ...
        "leakCategory", char(leakCat), ...
        "leakNote", char(leakNote));
end

useParfor = isfield(cfg, "q1") && isfield(cfg.q1, "useParfor") && cfg.q1.useParfor;
poolInfo = ensurePaperStudyParallelPool(cfg);
useParfor = useParfor && poolInfo.active;

tStart = tic;
fprintf("Q1 eval: %d methods x %d variant(s) 開姁E(parfor=%d, workers=%d, variant=%s)\n", ...
    nMethods, nVariants, useParfor, poolInfo.nWorkers, strjoin(variants, ","));
drawnow("limitrate");

methodPacks = cell(nMethods, 1);
if useParfor
    pool = gcp("nocreate");
    tasks = repmat(struct("fn", [], "args", {{}}, "label", "", "nOut", 1), nMethods, 1);
    for mi = 1:nMethods
        tasks(mi).fn = @runKrMethodBenchmarkMethod;
        tasks(mi).args = {methodKeys(mi), methodMetaCell{mi}, krBatchCell{mi}, variants, ...
            y, cohort.n, nSuccessVec(mi), cohort.nComplete, ...
            cfg, opts.commonCaseOnly, deployKrVariant};
        tasks(mi).label = char(methodKeys(mi));
        tasks(mi).nOut = 1;
    end
    pollSec = 5;
    if nMethods > 50
        pollSec = 10;
    end
    methodPacks = runParallelTaskBatch(pool, tasks, struct( ...
        "prefix", "Q1 eval", ...
        "pollSeconds", pollSec, ...
        "tStart", tStart));
else
    for mi = 1:nMethods
        methodPacks{mi} = runKrMethodBenchmarkMethod( ...
            methodKeys(mi), methodMetaCell{mi}, krBatchCell{mi}, variants, ...
            y, cohort.n, nSuccessVec(mi), cohort.nComplete, ...
            cfg, opts.commonCaseOnly, deployKrVariant);
        logStudyProgress("Q1 eval", mi, nMethods, char(methodKeys(mi)), tStart);
    end
end

rowPtr = 0;
for mi = 1:nMethods
    pack = methodPacks{mi};
    for vi = 1:nVariants
        rowPtr = rowPtr + 1;
        rows(rowPtr, :) = pack.rows(vi, :);
        cvResults{mi, vi} = pack.cvResults{vi};
    end
    if ~opts.commonCaseOnly
        if isfield(pack, "deployCalib") && ~isempty(pack.deployCalib)
            deployCalib{mi} = pack.deployCalib;
        elseif isfield(pack, "deployCalibChord") && ~isempty(pack.deployCalibChord)
            deployCalib{mi} = pack.deployCalibChord;
        end
    end
end

fprintf("Q1 eval: 完亁E%.0fs (parfor=%d)\n", toc(tStart), useParfor);
evalElapsedSeconds = toc(tStart);
drawnow("limitrate");

summaryTable = cell2table(rows(1:rowPtr, :), 'VariableNames', { ...
    'krMethodKey', 'variant', 'methodType', 'gridStart', 'gridWidth', 'gridValid', ...
    'label', 'leakCategory', 'leakNote', ...
    'nCohort', 'nUsed', 'nSuccessComplete', 'nComplete', ...
    'r2_loocv', 'mae_loocv', 'mae_loocv_sem', 'rmse_loocv', ...
    'relativeError_loocv', 'relativeError_loocv_sem'});
strCols = ["krMethodKey", "variant", "methodType", "label", "leakCategory", "leakNote"];
for si = 1:numel(strCols)
    c = strCols(si);
    if ismember(c, summaryTable.Properties.VariableNames)
        summaryTable.(c) = fillmissing(string(summaryTable.(c)), "constant", "");
    end
end

[summaryTable, bestRowIdx] = rankByMetrics(summaryTable, cfg);

bestKey = string(summaryTable.krMethodKey(bestRowIdx));
bestVariant = string(summaryTable.variant(bestRowIdx));

cvResultsByRow = cell(height(summaryTable), 1);
for ri = 1:height(summaryTable)
    key = string(summaryTable.krMethodKey(ri));
    var = string(summaryTable.variant(ri));
    mi = find(methodKeys == key, 1);
    vi = find(variants == var, 1);
    if isempty(mi) || isempty(vi)
        cvResultsByRow{ri} = struct("yTrue", [], "yPred", []);
    else
        cvResultsByRow{ri} = cvResults{mi, vi};
    end
end

pairTable = compareMethodsToBestWilcoxon(summaryTable, cvResultsByRow, struct( ...
    "metricField", "mae_loocv", ...
    "pairingMode", "all"));

writetable(summaryTable, fullfile(outDir, "kr_methods_loocv_summary.csv"));
writetable(pairTable, fullfile(outDir, "kr_methods_vs_best_pairs.csv"));
try
    exportPaperTables(summaryTable, fullfile(outDir, "table1_kr_methods"), ...
        "kr method LOOCV comparison");
catch me
    warning("run_kr_method_benchmark:PaperTableSkipped", ...
        "table1_kr_methods の LaTeX 出力をスキチE�E: %s", me.message);
end

results = struct();
results.createdAt = datetime("now");
results.analysisTag = opts.analysisTag;
results.useOutlierFilter = opts.useOutlierFilter;
results.commonCaseOnly = opts.commonCaseOnly;
results.summaryTable = summaryTable;
results.pairTable = pairTable;
results.bestMethodKey = char(bestKey);
results.bestVariant = char(bestVariant);
results.primaryMetric = cfg.metrics.primary;
results.cvResults = cvResults;
results.methodKeys = methodKeys;
results.q1Variants = variants;
results.cohort = cohort;
results.useParfor = useParfor;
results.elapsedSeconds = evalElapsedSeconds;

if ~opts.commonCaseOnly && cfg.cache.enabled
    calibFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_calib"));
    saveDeployCalibCache(cfg, opts.analysisTag, methodKeys, deployCalib, calibFp);
    results.deployCalib = deployCalib;
    results.deployCalibChord = deployCalib;
    results.deployCalibFingerprint = calibFp;
end

save(fullfile(outDir, "kr_benchmark_results.mat"), "results", "-v7");

fprintf("Q1 [%s]: best=%s, MAE=%.2f, RMSE=%.2f, R2=%.4f, n=%d\n", ...
    opts.analysisTag, bestKey + "_" + bestVariant, summaryTable.mae_loocv(bestRowIdx), ...
    summaryTable.rmse_loocv(bestRowIdx), summaryTable.r2_loocv(bestRowIdx), ...
    summaryTable.nUsed(bestRowIdx));

if cfg.figures.enabled
    plotMetricForest(summaryTable, "mae", fullfile(outDir, "fig1_mae_forest.png"), cfg);
    plotMetricForest(summaryTable, "rmse", fullfile(outDir, "fig1b_rmse_forest.png"), cfg);
    plotMetricForest(summaryTable, "r2", fullfile(outDir, "fig1c_r2_forest.png"), cfg);
    globalMaeClim = computeGlobalMaeHeatmapClim(summaryTable, [], cfg);
    globalRelErrorClim = computeGlobalRelErrorHeatmapClim(summaryTable, [], cfg);
    plotKrMethodHeatmaps(summaryTable, outDir, cfg, struct( ...
        "figPrefix", "fig2", ...
        "globalMaeClim", globalMaeClim, ...
        "globalRelErrorClim", globalRelErrorClim, ...
        "krVariant", deployKrVariant, ...
        "pairTable", pairTable));
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

function nSuccess = countKrSuccess(krExport, key, idsComplete)
succCol = "krSuccess_" + key;
krCol = "kr_" + key;
if ~ismember(succCol, krExport.Properties.VariableNames)
    if ismember(krCol, krExport.Properties.VariableNames)
        sub = krExport(ismember(krExport.id, idsComplete), :);
        nSuccess = nnz(isfinite(sub.(krCol)));
    else
        nSuccess = nan;
    end
    return;
end
sub = krExport(ismember(krExport.id, idsComplete), :);
nSuccess = nnz(sub.(succCol));
end
