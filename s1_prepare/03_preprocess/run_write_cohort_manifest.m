function run_write_cohort_manifest(opts)
%RUN_WRITE_COHORT_MANIFEST MAD 外れ値除去後の ID マニフェスト

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

if shouldSkipCompute(opts, cfg.paths.cohortManifest, true, "cohort")
    fprintf("既存: %s\n", cfg.paths.cohortManifest);
    return;
end

if ~isfile(cfg.paths.masterTable) || isPredictorArtifactStale(cfg.paths.masterTable)
    run_build_master_table(opts);
end

s = load(cfg.paths.masterTable, "masterTable");
tbl = s.masterTable;
reg = PredictorRegistry();
predictors = reg.paramPredictors;
outlierBasePredictors = reg.outlierBasePredictors;
outlierCfg = cfg.outlier;

missingOutlierCols = outlierBasePredictors(~ismember(outlierBasePredictors, ...
    string(tbl.Properties.VariableNames)));
if ~isempty(missingOutlierCols)
    warning("run_write_cohort_manifest:MissingOutlierColumns", ...
        "master に外れ値基準列がありません: %s。run_build_master_table を再実行してください。", ...
        strjoin(missingOutlierCols, ", "));
end

completeTable = buildCompleteCohortTable(tbl, outlierBasePredictors);

[analysisTable, outlierLog, outlierDiag] = removeOutliersForAnalysis( ...
    completeTable, predictors, predictors, outlierCfg);

manifest = struct();
manifest.createdAt = datetime("now");
manifest.idsComplete = completeTable.id;
manifest.idsKept = analysisTable.id;
manifest.idsRemoved = setdiff(completeTable.id, analysisTable.id);
manifest.outlierCfg = outlierCfg;
manifest.outlierLog = outlierLog;
manifest.outlierDiag = outlierDiag;
manifest.nComplete = height(completeTable);
manifest.nKept = height(analysisTable);
manifest.nRemoved = numel(manifest.idsRemoved);
manifest.predictors = predictors;
manifest.outlierBasePredictors = outlierBasePredictors;
manifest.cohortGatePredictors = outlierBasePredictors;
manifest.cohortFingerprint = cohortRegistryFingerprint();
manifest.predictorFingerprint = predictorRegistryFingerprint();
manifest.pipelineConfig = cfg;

idsKept = manifest.idsKept;
save(cfg.paths.cohortManifest, "manifest", "idsKept", "outlierCfg", "-v7");
fprintf("コホート manifest: kept=%d, removed=%d -> %s\n", ...
    manifest.nKept, manifest.nRemoved, cfg.paths.cohortManifest);
plotPreprocessFigures(cfg, "cohort");
end
