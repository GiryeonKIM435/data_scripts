function results = run_prepare_jeffreys_bi_iqr15(cfg, opts)
%RUN_PREPARE_JEFFREYS_BI_IQR15 Optional regenerator for Jeffreys IQR cohort
%
% Manuscript reproduction uses the shipped mats under outputs/prepare/:
%   tomato_with_fit_bi_iqr15.mat
%   jeffreys_fit_results_bi_iqr15.mat
%   master_analysis_table_bi_iqr15.mat
%   cohort_manifest_bi_iqr15.mat
% Re-running this with forceRecompute overwrites those and may change paper numbers.

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "skipIfExists")
    opts.skipIfExists = true;
end
if ~isfield(opts, "forceRecompute")
    opts.forceRecompute = false;
end

if ~isfile(cfg.paths.tomatoFiltered)
    error("run_prepare_jeffreys_bi_iqr15:NoFiltered", ...
        "tomato_filtered.mat がありません: %s", cfg.paths.tomatoFiltered);
end
if ~isfile(cfg.paths.krTable)
    error("run_prepare_jeffreys_bi_iqr15:NoKr", ...
        "kr_table.mat がありません: %s", cfg.paths.krTable);
end
if ~isfile(cfg.paths.creepWaveforms)
    error("run_prepare_jeffreys_bi_iqr15:NoWaveforms", ...
        "creep_waveforms.mat がありません: %s", cfg.paths.creepWaveforms);
end

fitPath = cfg.paths.tomatoWithFitBiIqr15;
masterPath = cfg.paths.masterTableBiIqr15;
manifestPath = cfg.paths.cohortManifestBiIqr15;
fitResultsPath = cfg.paths.jeffreysFitResultsBiIqr15;

dirs = unique(string({fileparts(fitPath), fileparts(masterPath)}));
for di = 1:numel(dirs)
    if ~isfolder(dirs(di))
        mkdir(dirs(di));
    end
end

skipOpts = struct("skipIfExists", opts.skipIfExists, "forceRecompute", opts.forceRecompute);

%% 1) Jeffreys fit with bilateral IQR reject
if shouldSkipCompute(skipOpts, fitPath, false)
    fprintf("Existing: %s\n", fitPath);
    sFit = load(fitPath, "fitResults", "metadataTomato");
    fitResults = sFit.fitResults;
    metadataTomato = sFit.metadataTomato;
else
    fprintf("Jeffreys fit (rejectParamOutliers=true, bilateral IQR, multiplier=1.5) ...\n");
    s = load(cfg.paths.tomatoFiltered, "tomatoFiltered");
    burgersOpts = burgersDefaultOpts();
    burgersOpts.rejectParamOutliers = true;
    burgersOpts.outlierIqrMultiplier = 1.5;
    [tomatoDataWithFit, fitResults, metadataTomato] = fitBurgersBatch( ...
        s.tomatoFiltered, burgersOpts);
    metadataTomato.rejectParamOutliers = true;
    metadataTomato.outlierIqrMultiplier = 1.5;
    metadataTomato.outlierMode = "bilateral_log10_k2_c1_c2";
    metadataTomato.note = "primary: Jeffreys bilateral IQR reject enabled";
    save(fitPath, "tomatoDataWithFit", "fitResults", "metadataTomato", "-v7");
    save(fitResultsPath, "fitResults", "metadataTomato", "-v7");
    fprintf("Saved: %s (success=%d/%d)\n", fitPath, ...
        nnz([fitResults.success]), numel(fitResults));
end

%% 2) master table
if shouldSkipCompute(skipOpts, masterPath, true)
    fprintf("既存: %s\n", masterPath);
else
    fprintf("master table (bilateral IQR fit) ...\n");
    sFit = load(fitPath, "tomatoDataWithFit", "metadataTomato");
    sKr = load(cfg.paths.krTable, "krExport", "metadata");
    sWf = load(cfg.paths.creepWaveforms, "waveformMatrix", "waveformIds", "timeGrid");
    reg = PredictorRegistry();

    masterTable = buildMasterPredictorTable(sFit.tomatoDataWithFit, sKr.krExport);
    waveformMatrix = sWf.waveformMatrix;
    waveformIds = sWf.waveformIds(:);
    timeGrid = sWf.timeGrid;

    [found, loc] = ismember(masterTable.id, waveformIds);
    if any(~found)
        warning("run_prepare_jeffreys_bi_iqr15:MissingWaveform", ...
            "波形のない ID: %s", mat2str(masterTable.id(~found).'));
    end
    wfAligned = nan(height(masterTable), size(waveformMatrix, 2));
    wfAligned(found, :) = waveformMatrix(loc(found), :);

    metadata = struct();
    metadata.createdAt = datetime("now");
    metadata.predictors = reg.paramPredictors;
    metadata.outlierBasePredictors = reg.outlierBasePredictors;
    metadata.predictorFingerprint = predictorRegistryFingerprint();
    metadata.targetName = reg.targetName;
    metadata.jeffreysBiIqr15 = true;
    if isfield(sFit, "metadataTomato")
        metadata.sourceTomato = sFit.metadataTomato;
    end
    if isfield(sKr, "metadata")
        metadata.krTableMetadata = sKr.metadata;
    end

    masterTable = sortrows(masterTable, "id");
    waveformMatrix = wfAligned;
    save(masterPath, "masterTable", "waveformMatrix", "timeGrid", "metadata", "-v7");
    fprintf("master テーブル: %d 行 -> %s\n", height(masterTable), masterPath);
end

%% 3) cohort manifest
if shouldSkipCompute(skipOpts, manifestPath, true, "cohort")
    fprintf("既存: %s\n", manifestPath);
    sm = load(manifestPath, "manifest");
    manifest = sm.manifest;
else
    fprintf("cohort manifest (bilateral IQR fit) ...\n");
    s = load(masterPath, "masterTable");
    tbl = s.masterTable;
    reg = PredictorRegistry();
    predictors = reg.paramPredictors;
    outlierBasePredictors = reg.outlierBasePredictors;
    outlierCfg = OutlierConfig();

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
    manifest.jeffreysBiIqr15 = true;
    manifest.cohortFingerprint = cohortRegistryFingerprint();
    manifest.predictorFingerprint = predictorRegistryFingerprint();

    idsKept = manifest.idsKept;
    save(manifestPath, "manifest", "idsKept", "outlierCfg", "-v7");
    fprintf("コホート manifest: complete=%d, kept=%d -> %s\n", ...
        manifest.nComplete, manifest.nKept, manifestPath);
end

results = struct();
results.createdAt = datetime("now");
results.fitPath = fitPath;
results.masterPath = masterPath;
results.manifestPath = manifestPath;
results.nFitSuccess = nnz([fitResults.success]);
results.nFitTotal = numel(fitResults);
results.nComplete = manifest.nComplete;
results.nKept = manifest.nKept;
fprintf("prepare jeffreys cohort: fit success=%d/%d, complete=%d, kept=%d\n", ...
    results.nFitSuccess, results.nFitTotal, results.nComplete, results.nKept);
end
