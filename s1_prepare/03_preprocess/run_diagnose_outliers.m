function run_diagnose_outliers(opts)
%RUN_DIAGNOSE_OUTLIERS 外れ値診断

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

if ~isfile(cfg.paths.masterTable) || isPredictorArtifactStale(cfg.paths.masterTable)
    run_build_master_table(opts);
end

s = load(cfg.paths.masterTable, "masterTable");
tbl = s.masterTable;
reg = PredictorRegistry();
predictors = reg.paramPredictors;
outlierBasePredictors = reg.outlierBasePredictors;
completeTable = buildCompleteCohortTable(tbl, outlierBasePredictors);
outlierCfg = cfg.outlier;
outlierCfg.modeYieldMad = false;
outlierCfg.modeBaseXMad = false;

[~, outlierLog, outlierDiag] = removeOutliersForAnalysis( ...
    completeTable, predictors, predictors, outlierCfg);

outlierCfgApply = cfg.outlier;
[analysisTable, outlierLogApply, outlierDiagApply] = removeOutliersForAnalysis( ...
    completeTable, predictors, predictors, outlierCfgApply);

diagnostic = struct();
diagnostic.createdAt = datetime("now");
diagnostic.nSource = height(completeTable);
diagnostic.nMaster = height(tbl);
diagnostic.nWouldRemove = height(completeTable) - height(analysisTable);
diagnostic.outlierLog = outlierLogApply;
diagnostic.outlierDiag = outlierDiagApply;
diagnostic.idsKept = analysisTable.id;
diagnostic.idsRemoved = setdiff(completeTable.id, analysisTable.id);

save(cfg.paths.outlierDiagnostic, "diagnostic", "outlierDiag", "-v7");
fprintf("外れ値診断: 除去候補 %d / %d -> %s\n", ...
    diagnostic.nWouldRemove, diagnostic.nSource, cfg.paths.outlierDiagnostic);
plotPreprocessFigures(cfg, "outliers");
end