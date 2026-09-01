function results = run_prepare_jeffreys_harvest_day_subset(cfg, opts)
%RUN_PREPARE_JEFFREYS_HARVEST_DAY_SUBSET Restrict manuscript cohort to one harvest day
%
% Does not re-fit Jeffreys. Filters bi_iqr15 master/manifest by harvestBatchAMaxId
% (raw-aligned: id<=50 -> 2026-04-23, else 2026-04-29).

if nargin < 1 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "day")
    error("run_prepare_jeffreys_harvest_day_subset:NoDay", ...
        "opts.day must be ""0423"" or ""0429"".");
end
if ~isfield(opts, "skipIfExists")
    opts.skipIfExists = true;
end
if ~isfield(opts, "forceRecompute")
    opts.forceRecompute = false;
end

day = string(opts.day);
if day == "0423" || day == "2026-04-23"
    dayLabel = "2026-04-23";
    suf = "harvest_0423";
    tag = "sens_harvest_0423";
    pickEarly = true;
elseif day == "0429" || day == "2026-04-29"
    dayLabel = "2026-04-29";
    suf = "harvest_0429";
    tag = "sens_harvest_0429";
    pickEarly = false;
else
    error("run_prepare_jeffreys_harvest_day_subset:BadDay", "Unsupported day: %s", day);
end

maxIdBatchA = 50;
if isfield(cfg, "paper") && isfield(cfg.paper, "harvestBatchAMaxId") ...
        && isfinite(cfg.paper.harvestBatchAMaxId)
    maxIdBatchA = double(cfg.paper.harvestBatchAMaxId);
end

baseMaster = cfg.paths.masterTableBiIqr15;
baseManifest = cfg.paths.cohortManifestBiIqr15;
if ~isfile(baseMaster) || ~isfile(baseManifest)
    error("run_prepare_jeffreys_harvest_day_subset:MissingBaseline", ...
        "Manuscript bi_iqr15 master/manifest missing under outputs/prepare/.");
end

prepareOut = fullfile(cfg.studyRoot, "outputs", "prepare", "03_preprocess");
if ~isfolder(prepareOut)
    mkdir(prepareOut);
end
masterPath = fullfile(prepareOut, sprintf("master_analysis_table_%s.mat", suf));
manifestPath = fullfile(prepareOut, sprintf("cohort_manifest_%s.mat", suf));

skipOpts = struct("skipIfExists", opts.skipIfExists, "forceRecompute", opts.forceRecompute);
if shouldSkipCompute(skipOpts, masterPath, true) && shouldSkipCompute(skipOpts, manifestPath, true, "cohort")
    fprintf("Existing harvest subset: %s / %s\n", masterPath, manifestPath);
    sm = load(manifestPath, "manifest");
    results = struct("analysisTag", tag, "dayLabel", dayLabel, ...
        "masterPath", masterPath, "manifestPath", manifestPath, ...
        "nComplete", sm.manifest.nComplete, "nKept", sm.manifest.nKept, ...
        "harvestBatchAMaxId", maxIdBatchA);
    return;
end

sM = load(baseMaster);
masterTable = sM.masterTable;
waveformMatrix = [];
timeGrid = [];
if isfield(sM, "waveformMatrix")
    waveformMatrix = sM.waveformMatrix;
end
if isfield(sM, "timeGrid")
    timeGrid = sM.timeGrid;
end
metadata = struct();
if isfield(sM, "metadata")
    metadata = sM.metadata;
end

sm0 = load(baseManifest, "manifest");
manifest0 = sm0.manifest;
idsComplete0 = double(manifest0.idsComplete(:));
idsKept0 = double(manifest0.idsKept(:));

if pickEarly
    dayMaskComplete = idsComplete0 <= maxIdBatchA;
    dayMaskKept = idsKept0 <= maxIdBatchA;
else
    dayMaskComplete = idsComplete0 > maxIdBatchA;
    dayMaskKept = idsKept0 > maxIdBatchA;
end
idsComplete = idsComplete0(dayMaskComplete);
idsKept = idsKept0(dayMaskKept);

keepRows = ismember(double(masterTable.id), idsComplete);
masterTable = sortrows(masterTable(keepRows, :), "id");

% Re-align waveforms by id from baseline load
if isfield(sM, "waveformMatrix") && isfield(sM, "masterTable")
    baseIds = double(sM.masterTable.id(:));
    [found, loc] = ismember(double(masterTable.id), baseIds);
    wfAligned = nan(height(masterTable), size(sM.waveformMatrix, 2));
    wfAligned(found, :) = sM.waveformMatrix(loc(found), :);
    waveformMatrix = wfAligned;
end

metadata.createdAt = datetime("now");
metadata.harvestDaySubset = char(dayLabel);
metadata.harvestBatchAMaxId = maxIdBatchA;
metadata.analysisTag = tag;
metadata.sourceMaster = string(baseMaster);

manifest = manifest0;
manifest.createdAt = datetime("now");
manifest.idsComplete = idsComplete(:);
manifest.idsKept = idsKept(:);
manifest.idsRemoved = setdiff(idsComplete(:), idsKept(:));
manifest.nComplete = numel(idsComplete);
manifest.nKept = numel(idsKept);
manifest.nRemoved = numel(manifest.idsRemoved);
manifest.harvestDaySubset = char(dayLabel);
manifest.harvestBatchAMaxId = maxIdBatchA;
manifest.analysisTag = tag;

save(masterPath, "masterTable", "waveformMatrix", "timeGrid", "metadata", "-v7");
idsKept = manifest.idsKept; %#ok<NASGU>
outlierCfg = [];
if isfield(manifest0, "outlierCfg")
    outlierCfg = manifest0.outlierCfg;
end
save(manifestPath, "manifest", "idsKept", "outlierCfg", "-v7");

fprintf("Harvest subset %s (id rule maxA=%d): complete=%d, kept=%d\n", ...
    dayLabel, maxIdBatchA, manifest.nComplete, manifest.nKept);
fprintf("  master -> %s\n", masterPath);
fprintf("  manifest -> %s\n", manifestPath);

results = struct();
results.createdAt = datetime("now");
results.analysisTag = tag;
results.dayLabel = dayLabel;
results.masterPath = masterPath;
results.manifestPath = manifestPath;
results.nComplete = manifest.nComplete;
results.nKept = manifest.nKept;
results.harvestBatchAMaxId = maxIdBatchA;
results.idsComplete = idsComplete(:);
end
