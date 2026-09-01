function results = run_prepare_jeffreys_no_iqr(cfg, opts)
%RUN_PREPARE_JEFFREYS_NO_IQR Sensitivity: Jeffreys fit without bilateral IQR reject
%
% Uses baseline tomato_filtered / kr_table / creep_waveforms (visual exclusions
% unchanged). Writes separate mats; does not overwrite *_bi_iqr15.mat.

if nargin < 1 || isempty(cfg)
    cfg = PaperStudyConfig();
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
    error("run_prepare_jeffreys_no_iqr:NoFiltered", ...
        "tomato_filtered.mat missing: %s", cfg.paths.tomatoFiltered);
end
if ~isfile(cfg.paths.krTable)
    error("run_prepare_jeffreys_no_iqr:NoKr", ...
        "kr_table.mat missing: %s", cfg.paths.krTable);
end
if ~isfile(cfg.paths.creepWaveforms)
    error("run_prepare_jeffreys_no_iqr:NoWaveforms", ...
        "creep_waveforms.mat missing: %s", cfg.paths.creepWaveforms);
end

fitPath = cfg.paths.tomatoWithFitNoIqr;
masterPath = cfg.paths.masterTableNoIqr;
manifestPath = cfg.paths.cohortManifestNoIqr;
fitResultsPath = cfg.paths.jeffreysFitResultsNoIqr;

dirs = unique(string({fileparts(fitPath), fileparts(masterPath)}));
for di = 1:numel(dirs)
    if ~isfolder(dirs(di))
        mkdir(dirs(di));
    end
end

skipOpts = struct("skipIfExists", opts.skipIfExists, "forceRecompute", opts.forceRecompute);

%% 1) Jeffreys fit without IQR reject
if shouldSkipCompute(skipOpts, fitPath, false)
    fprintf("Existing: %s\n", fitPath);
    sFit = load(fitPath, "fitResults", "metadataTomato");
    fitResults = sFit.fitResults;
    metadataTomato = sFit.metadataTomato;
else
    fprintf("Jeffreys fit (rejectParamOutliers=false; sensitivity no-IQR) ...\n");
    s = load(cfg.paths.tomatoFiltered, "tomatoFiltered");
    burgersOpts = burgersDefaultOpts();
    burgersOpts.rejectParamOutliers = false;
    [tomatoDataWithFit, fitResults, metadataTomato] = fitBurgersBatch( ...
        s.tomatoFiltered, burgersOpts);
    metadataTomato.rejectParamOutliers = false;
    metadataTomato.note = "sensitivity: Jeffreys without bilateral IQR reject";
    metadataTomato.analysisTag = "sens_no_iqr";
    save(fitPath, "tomatoDataWithFit", "fitResults", "metadataTomato", "-v7");
    save(fitResultsPath, "fitResults", "metadataTomato", "-v7");
    fprintf("Saved: %s (success=%d/%d)\n", fitPath, ...
        nnz([fitResults.success]), numel(fitResults));
end

%% 2) master table
if shouldSkipCompute(skipOpts, masterPath, true)
    fprintf("Existing: %s\n", masterPath);
else
    fprintf("master table (no IQR fit) ...\n");
    sFit = load(fitPath, "tomatoDataWithFit", "metadataTomato");
    sKr = load(cfg.paths.krTable, "krExport", "metadata");
    sWf = load(cfg.paths.creepWaveforms, "waveformMatrix", "waveformIds", "timeGrid");
    reg = PredictorRegistry();

    masterTable = buildMasterPredictorTable(sFit.tomatoDataWithFit, sKr.krExport);
    waveformIds = sWf.waveformIds(:);
    [found, loc] = ismember(masterTable.id, waveformIds);
    wfAligned = nan(height(masterTable), size(sWf.waveformMatrix, 2));
    wfAligned(found, :) = sWf.waveformMatrix(loc(found), :);

    metadata = struct();
    metadata.createdAt = datetime("now");
    metadata.predictors = reg.paramPredictors;
    metadata.outlierBasePredictors = reg.outlierBasePredictors;
    metadata.predictorFingerprint = predictorRegistryFingerprint();
    metadata.targetName = reg.targetName;
    metadata.jeffreysNoIqr = true;
    metadata.analysisTag = "sens_no_iqr";
    if isfield(sFit, "metadataTomato")
        metadata.sourceTomato = sFit.metadataTomato;
    end
    if isfield(sKr, "metadata")
        metadata.krTableMetadata = sKr.metadata;
    end

    masterTable = sortrows(masterTable, "id");
    waveformMatrix = wfAligned;
    timeGrid = sWf.timeGrid;
    save(masterPath, "masterTable", "waveformMatrix", "timeGrid", "metadata", "-v7");
    fprintf("master: %d rows -> %s\n", height(masterTable), masterPath);
end

%% 3) cohort manifest
if shouldSkipCompute(skipOpts, manifestPath, true, "cohort")
    fprintf("Existing: %s\n", manifestPath);
    sm = load(manifestPath, "manifest");
    manifest = sm.manifest;
else
    fprintf("cohort manifest (no IQR) ...\n");
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
    manifest.jeffreysNoIqr = true;
    manifest.analysisTag = "sens_no_iqr";
    manifest.cohortFingerprint = cohortRegistryFingerprint();
    manifest.predictorFingerprint = predictorRegistryFingerprint();

    idsKept = manifest.idsKept;
    save(manifestPath, "manifest", "idsKept", "outlierCfg", "-v7");
    fprintf("manifest: complete=%d, kept=%d -> %s\n", ...
        manifest.nComplete, manifest.nKept, manifestPath);
end

results = struct();
results.createdAt = datetime("now");
results.analysisTag = "sens_no_iqr";
results.fitPath = fitPath;
results.masterPath = masterPath;
results.manifestPath = manifestPath;
results.nFitSuccess = nnz([fitResults.success]);
results.nFitTotal = numel(fitResults);
results.nComplete = manifest.nComplete;
results.nKept = manifest.nKept;
fprintf("prepare sens_no_iqr: fit success=%d/%d, complete=%d, kept=%d\n", ...
    results.nFitSuccess, results.nFitTotal, results.nComplete, results.nKept);
end
