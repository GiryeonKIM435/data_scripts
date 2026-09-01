function results = run_prepare_jeffreys_incl_visual(cfg, opts)
%RUN_PREPARE_JEFFREYS_INCL_VISUAL Sensitivity: append visual-excluded IDs 8,71
%
% Single factor = visual exclusion only. Primary Jeffreys bi_iqr15 complete
% cohort is frozen (no batch IQR recompute). Target complete n = 87 + up to 2.
%
% Writes separate *_incl_visual.mat products; does not overwrite manuscript mats.
% If legacy products were built with batch re-IQR (n~86), set forceRecompute=true.

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
if ~isfield(opts, "forceKeepIds")
    opts.forceKeepIds = [8; 71];
end

forceKeepIds = double(opts.forceKeepIds(:));
analysisTag = "sens_incl_visual";
cfgBase = cfg;
cfgSens = applyJeffreysInclVisualPaths(cfg);

filtPath = cfgSens.paths.tomatoFiltered;
krPath = cfgSens.paths.krTable;
fitPath = cfgSens.paths.tomatoWithFit;
fitResultsPath = cfgSens.paths.jeffreysFitResults;
masterPath = cfgSens.paths.masterTable;
manifestPath = cfgSens.paths.cohortManifest;

primaryFitPath = cfgBase.paths.tomatoWithFitBiIqr15;
primaryMasterPath = cfgBase.paths.masterTableBiIqr15;
primaryManifestPath = cfgBase.paths.cohortManifestBiIqr15;
primaryKrPath = cfgBase.paths.krTable;

for p = [string(primaryFitPath), string(primaryMasterPath), ...
        string(primaryManifestPath), string(primaryKrPath)]
    if ~isfile(p)
        error("run_prepare_jeffreys_incl_visual:MissingPrimary", ...
            "Primary bi_iqr15 product missing: %s", p);
    end
end

dirs = unique(string({fileparts(filtPath), fileparts(krPath), ...
    fileparts(fitPath), fileparts(masterPath)}));
for di = 1:numel(dirs)
    if ~isfolder(dirs(di))
        mkdir(dirs(di));
    end
end

skipOpts = struct("skipIfExists", opts.skipIfExists, "forceRecompute", opts.forceRecompute);

sMan0 = load(primaryManifestPath, "manifest");
idsPrimaryComplete = double(sMan0.manifest.idsComplete(:));
nPrimaryComplete = numel(idsPrimaryComplete);
extraIdsWanted = setdiff(forceKeepIds, idsPrimaryComplete, "stable");

fprintf("incl_visual: primary complete n=%d; append candidates %s (IQR frozen)\n", ...
    nPrimaryComplete, mat2str(extraIdsWanted.'));

% Legacy products used batch re-IQR (often n~86). Invalidate if missing freeze marker.
if ~skipOpts.forceRecompute && isfile(manifestPath)
    try
        smOld = load(manifestPath, "manifest");
        manOld = smOld.manifest;
        hasFreeze = isfield(manOld, "note") && contains(string(manOld.note), "frozen");
        hasPrimary = isfield(manOld, "idsPrimaryComplete") ...
            && numel(manOld.idsPrimaryComplete) == nPrimaryComplete;
        if ~(hasFreeze && hasPrimary)
            warning("run_prepare_jeffreys_incl_visual:StaleLegacy", ...
                ["Existing incl_visual products lack primary-IQR-freeze metadata ", ...
                "(likely batch re-IQR, n=%d). Forcing recompute."], manOld.nComplete);
            skipOpts.forceRecompute = true;
        end
    catch
        skipOpts.forceRecompute = true;
    end
end

%% 1) filtered: primary filtered ∪ forceKeep extras (record only; no re-IQR)
if shouldSkipCompute(skipOpts, filtPath, false)
    fprintf("Existing: %s\n", filtPath);
    sF = load(filtPath, "tomatoFiltered", "metadataFiltered");
    tomatoFiltered = sF.tomatoFiltered;
else
    if ~isfile(cfgBase.paths.tomatoFiltered)
        error("run_prepare_jeffreys_incl_visual:NoFilteredBase", ...
            "Baseline tomato_filtered.mat missing.");
    end
    if ~isfile(cfgBase.paths.tomatoDataset) || ~isfile(cfgBase.paths.noiseProfile)
        error("run_prepare_jeffreys_incl_visual:MissingBase", ...
            "Need tomato_dataset.mat and noise_profile.mat under outputs/prepare/.");
    end
    sFilt0 = load(cfgBase.paths.tomatoFiltered, "tomatoFiltered", "metadataFiltered");
    sData = load(cfgBase.paths.tomatoDataset, "tomatoData");
    sNoise = load(cfgBase.paths.noiseProfile, "noiseStats");

    tomatoFiltered = sFilt0.tomatoFiltered;
    if ~isempty(extraIdsWanted)
        pipeCfg = PipelineConfig();
        pipeCfg.detectYield.forceKeepIds = extraIdsWanted;
        [tomatoExtra, metaExtra] = filterTomatoByYield( ...
            sData.tomatoData, sNoise.noiseStats, pipeCfg);
        idsExtraGot = arrayfun(@(x) double(x.id), tomatoExtra);
        idsExtraGot = idsExtraGot(:);
        keepExtra = ismember(idsExtraGot, extraIdsWanted);
        tomatoExtra = tomatoExtra(keepExtra);
        baseIds = arrayfun(@(x) double(x.id), tomatoFiltered);
        drop = ismember(baseIds(:), idsExtraGot(keepExtra));
        tomatoFiltered = [tomatoFiltered(~drop), tomatoExtra];
        [~, ord] = sort(arrayfun(@(x) double(x.id), tomatoFiltered));
        tomatoFiltered = tomatoFiltered(ord);
        metadataFiltered = sFilt0.metadataFiltered;
        metadataFiltered.forceKeepIds = forceKeepIds(:).';
        metadataFiltered.extraIdsAppended = idsExtraGot(keepExtra).';
        if isstruct(metaExtra)
            metadataFiltered.forceKeepFilter = metaExtra;
        end
    else
        metadataFiltered = sFilt0.metadataFiltered;
        metadataFiltered.forceKeepIds = forceKeepIds(:).';
        metadataFiltered.extraIdsAppended = zeros(0, 1);
    end
    metadataFiltered.note = ...
        "sensitivity: primary filtered + visual IDs; primary IQR cohort frozen";
    noiseStats = sNoise.noiseStats;
    save(filtPath, "tomatoFiltered", "metadataFiltered", "noiseStats", "-v7");
    fprintf("Saved: %s (kept=%d)\n", filtPath, numel(tomatoFiltered));
end

%% 2) kr table: baseline + estimate missing extras only
if shouldSkipCompute(skipOpts, krPath, false)
    fprintf("Existing: %s\n", krPath);
else
    fprintf("kr estimate (%s: missing append IDs only)...\n", analysisTag);
    sKr0 = load(primaryKrPath, "krExport", "metadata");
    sRaw = load(cfgBase.paths.tomatoDataset, "tomatoData");
    sNoise = load(cfgBase.paths.noiseProfile, "noiseStats");

    baseIds = double(sKr0.krExport.id(:));
    allIds = arrayfun(@(x) double(x.id), tomatoFiltered);
    allIds = allIds(:);
    missingIds = setdiff(intersect(allIds, forceKeepIds), baseIds, "stable");

    pipeCfg = PipelineConfig();
    if isempty(missingIds)
        krExport = sKr0.krExport;
        metadata = sKr0.metadata;
        fprintf("No additional kr estimation needed\n");
    else
        missMask = ismember(allIds, missingIds);
        tomatoMiss = tomatoFiltered(missMask);
        fprintf("Estimating missing IDs: %s\n", mat2str(missingIds.'));
        [krMiss, metaMiss] = estimateKrTable( ...
            tomatoMiss, sRaw.tomatoData, sNoise.noiseStats, pipeCfg, []);
        krExport = mergeKrExportTablesLocal(sKr0.krExport, krMiss);
        metadata = sKr0.metadata;
        metadata.mergedMissingIds = missingIds(:).';
        if isstruct(metaMiss)
            metadata.missingEstimate = metaMiss;
        end
    end
    keep = ismember(double(krExport.id), allIds);
    krExport = krExport(keep, :);
    [~, ord] = sort(double(krExport.id));
    krExport = krExport(ord, :);
    metadata.note = "sensitivity: primary kr + visual-ID append; no re-IQR";
    save(krPath, "krExport", "metadata", "-v7");
    fprintf("Saved: %s (n=%d)\n", krPath, height(krExport));
end

%% 3) Jeffreys fit: keep primary fit; fit extras only (no batch IQR)
if shouldSkipCompute(skipOpts, fitPath, false)
    fprintf("Existing: %s\n", fitPath);
    sFit = load(fitPath, "fitResults", "metadataTomato");
    fitResults = sFit.fitResults;
    metadataTomato = sFit.metadataTomato;
else
    fprintf("Jeffreys fit (append IDs only, rejectParamOutliers=false)...\n");
    sFit0 = load(primaryFitPath, "tomatoDataWithFit", "fitResults", "metadataTomato");
    tomatoDataWithFit = sFit0.tomatoDataWithFit;
    fitResults = sFit0.fitResults;
    metadataTomato = sFit0.metadataTomato;

    primaryFitIds = arrayfun(@(x) double(x.id), tomatoDataWithFit);
    primaryFitIds = primaryFitIds(:);
    % Fit only IDs not already in primary complete (no batch IQR)
    appendIds = setdiff(forceKeepIds, idsPrimaryComplete, "stable");

    appendedIds = zeros(0, 1);
    failedIds = zeros(0, 1);
    if isempty(appendIds)
        fprintf("No append IDs to fit (already in primary complete)\n");
    else
        idsFilt = arrayfun(@(x) double(x.id), tomatoFiltered);
        idsFilt = idsFilt(:);
        for ii = 1:numel(appendIds)
            id = appendIds(ii);
            locF = find(idsFilt == id, 1);
            if isempty(locF)
                warning("run_prepare_jeffreys_incl_visual:NoFilteredId", ...
                    "ID %g not in filtered set; skip fit", id);
                failedIds(end + 1, 1) = id; %#ok<AGROW>
                continue;
            end
            burgersOpts = burgersDefaultOpts();
            burgersOpts.rejectParamOutliers = false;
            [tomatoOne, fitOne, ~] = fitBurgersBatch(tomatoFiltered(locF), burgersOpts);
            if isempty(fitOne) || ~fitOne(1).success
                fprintf("  ID %g: Jeffreys fit FAILED\n", id);
                failedIds(end + 1, 1) = id; %#ok<AGROW>
                continue;
            end
            % Replace existing primary entry for this id if any, else append
            locP = find(primaryFitIds == id, 1);
            if isempty(locP)
                tomatoDataWithFit(end + 1) = tomatoOne; %#ok<AGROW>
                fitResults(end + 1) = fitOne; %#ok<AGROW>
                primaryFitIds(end + 1, 1) = id; %#ok<AGROW>
            else
                tomatoDataWithFit(locP) = tomatoOne;
                fitResults(locP) = fitOne;
            end
            appendedIds(end + 1, 1) = id; %#ok<AGROW>
            fprintf("  ID %g: Jeffreys fit OK (no batch IQR)\n", id);
        end
        [~, ord] = sort(arrayfun(@(x) double(x.id), tomatoDataWithFit));
        tomatoDataWithFit = tomatoDataWithFit(ord);
        fitResults = fitResults(ord);
    end

    metadataTomato.rejectParamOutliers = false;
    metadataTomato.outlierMode = "none_append_only";
    metadataTomato.note = ...
        "primary IQR cohort frozen; visual IDs force-appended without re-IQR";
    metadataTomato.forceKeepIds = forceKeepIds(:).';
    metadataTomato.appendedIds = appendedIds(:).';
    metadataTomato.failedAppendIds = failedIds(:).';
    metadataTomato.idsPrimaryComplete = idsPrimaryComplete(:).';
    metadataTomato.analysisTag = analysisTag;
    save(fitPath, "tomatoDataWithFit", "fitResults", "metadataTomato", "-v7");
    save(fitResultsPath, "fitResults", "metadataTomato", "-v7");
    fprintf("Saved: %s (appended=%s, failed=%s)\n", fitPath, ...
        mat2str(appendedIds.'), mat2str(failedIds.'));
end

if ~exist("appendedIds", "var")
    appendedIds = zeros(0, 1);
    if isfield(metadataTomato, "appendedIds")
        appendedIds = double(metadataTomato.appendedIds(:));
    end
end
if ~exist("failedIds", "var")
    failedIds = zeros(0, 1);
    if isfield(metadataTomato, "failedAppendIds")
        failedIds = double(metadataTomato.failedAppendIds(:));
    end
end

%% 4) master table: primary master rows + successful append rows
if shouldSkipCompute(skipOpts, masterPath, true)
    fprintf("Existing: %s\n", masterPath);
else
    fprintf("master table (%s)...\n", analysisTag);
    sFit = load(fitPath, "tomatoDataWithFit", "metadataTomato");
    sKr = load(krPath, "krExport", "metadata");
    sM0 = load(primaryMasterPath, "masterTable", "waveformMatrix", "timeGrid", "metadata");
    reg = PredictorRegistry();

    masterFull = buildMasterPredictorTable(sFit.tomatoDataWithFit, sKr.krExport);
    keepIds = unique([idsPrimaryComplete(:); appendedIds(:)], "stable");
    masterTable = masterFull(ismember(double(masterFull.id), keepIds), :);
    masterTable = sortrows(masterTable, "id");

    waveformMatrix = [];
    timeGrid = [];
    if isfile(cfgBase.paths.creepWaveforms)
        sWf = load(cfgBase.paths.creepWaveforms, "waveformMatrix", "waveformIds", "timeGrid");
        waveformIds = sWf.waveformIds(:);
        [found, loc] = ismember(masterTable.id, waveformIds);
        wfAligned = nan(height(masterTable), size(sWf.waveformMatrix, 2));
        wfAligned(found, :) = sWf.waveformMatrix(loc(found), :);
        waveformMatrix = wfAligned;
        timeGrid = sWf.timeGrid;
    elseif isfield(sM0, "waveformMatrix")
        waveformMatrix = sM0.waveformMatrix;
        timeGrid = sM0.timeGrid;
    end

    metadata = struct();
    metadata.createdAt = datetime("now");
    metadata.predictors = reg.paramPredictors;
    metadata.outlierBasePredictors = reg.outlierBasePredictors;
    metadata.predictorFingerprint = predictorRegistryFingerprint();
    metadata.targetName = reg.targetName;
    metadata.jeffreysBiIqr15 = true;
    metadata.analysisTag = analysisTag;
    metadata.forceKeepIds = forceKeepIds(:).';
    metadata.appendedIds = appendedIds(:).';
    metadata.idsPrimaryComplete = idsPrimaryComplete(:).';
    metadata.note = ...
        "primary IQR cohort frozen; visual IDs force-appended without re-IQR";
    if isfield(sFit, "metadataTomato")
        metadata.sourceTomato = sFit.metadataTomato;
    end
    if isfield(sKr, "metadata")
        metadata.krTableMetadata = sKr.metadata;
    end

    save(masterPath, "masterTable", "waveformMatrix", "timeGrid", "metadata", "-v7");
    fprintf("master: %d rows -> %s\n", height(masterTable), masterPath);
end

%% 5) cohort manifest: primary complete ∪ successful extras that pass gates
if shouldSkipCompute(skipOpts, manifestPath, true, "cohort")
    fprintf("Existing: %s\n", manifestPath);
    sm = load(manifestPath, "manifest");
    manifest = sm.manifest;
else
    fprintf("cohort manifest (%s)...\n", analysisTag);
    s = load(masterPath, "masterTable");
    tbl = s.masterTable;
    reg = PredictorRegistry();
    predictors = reg.paramPredictors;
    outlierBasePredictors = reg.outlierBasePredictors;
    outlierCfg = OutlierConfig();

    completeFromMaster = buildCompleteCohortTable(tbl, outlierBasePredictors);
    idsFromMaster = double(completeFromMaster.id(:));
    % Freeze primary complete; add only successfully fitted extras that pass gates
    idsExtraOk = intersect(appendedIds(:), idsFromMaster, "stable");
    idsComplete = unique([idsPrimaryComplete(:); idsExtraOk(:)], "stable");
    completeTable = tbl(ismember(double(tbl.id), idsComplete), :);
    completeTable = sortrows(completeTable, "id");

    [analysisTable, outlierLog, outlierDiag] = removeOutliersForAnalysis( ...
        completeTable, predictors, predictors, outlierCfg);

    nWanted = nPrimaryComplete + numel(forceKeepIds);
    if numel(idsComplete) < nWanted
        fprintf(["WARNING: complete n=%d < target ~%d. " ...
            "Appended OK=%s; failed/missing gate=%s. n may be 87-89.\n"], ...
            numel(idsComplete), nWanted, ...
            mat2str(idsExtraOk.'), mat2str(setdiff(forceKeepIds, idsComplete).'));
    end

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
    manifest.analysisTag = analysisTag;
    manifest.forceKeepIds = forceKeepIds(:).';
    manifest.appendedIds = appendedIds(:).';
    manifest.failedAppendIds = failedIds(:).';
    manifest.idsPrimaryComplete = idsPrimaryComplete(:).';
    manifest.note = ...
        "primary IQR cohort frozen; visual IDs force-appended without re-IQR";
    manifest.cohortFingerprint = cohortRegistryFingerprint();
    manifest.predictorFingerprint = predictorRegistryFingerprint();

    idsKept = manifest.idsKept;
    save(manifestPath, "manifest", "idsKept", "outlierCfg", "-v7");
    fprintf("manifest: complete=%d (primary=%d + extra=%d), kept=%d -> %s\n", ...
        manifest.nComplete, nPrimaryComplete, numel(idsExtraOk), ...
        manifest.nKept, manifestPath);
end

results = struct();
results.createdAt = datetime("now");
results.analysisTag = analysisTag;
results.fitPath = fitPath;
results.masterPath = masterPath;
results.manifestPath = manifestPath;
results.nFiltered = numel(tomatoFiltered);
results.nFitSuccess = nnz([fitResults.success]);
results.nFitTotal = numel(fitResults);
results.nComplete = manifest.nComplete;
results.nKept = manifest.nKept;
results.nPrimaryComplete = nPrimaryComplete;
results.forceKeepIds = forceKeepIds;
results.appendedIds = appendedIds;
results.failedAppendIds = failedIds;
fprintf("prepare %s: filtered=%d, fit=%d/%d, complete=%d (primary=%d), kept=%d\n", ...
    analysisTag, results.nFiltered, results.nFitSuccess, results.nFitTotal, ...
    results.nComplete, nPrimaryComplete, results.nKept);
end

function out = mergeKrExportTablesLocal(baseT, addT)
baseIds = double(baseT.id);
addIds = double(addT.id);
drop = ismember(baseIds, addIds);
out = [baseT(~drop, :); addT];
[~, ord] = sort(double(out.id));
out = out(ord, :);
end
