function cohort = loadCohort(masterMatFile, manifestMatFile, opts)
%loadCohort master + manifest から解析コホートを構築（固定 ID 集合）

if nargin < 3
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = true;
end

reg = PredictorRegistry();
predictors = reg.paramPredictors;

s = load(masterMatFile, "masterTable", "waveformMatrix", "timeGrid", "metadata");
if ~isfield(s, "masterTable")
    error("loadCohort:MissingMaster", "masterTable がありません: %s", masterMatFile);
end

tbl = s.masterTable;
colNames = string(tbl.Properties.VariableNames);
missingCols = predictors(~ismember(predictors, colNames));
if ~isempty(missingCols)
    msg = "master に説明変数列がありません: %s。ensureAnalysisCohortFresh または doPreprocess=true で master を再構築してください。";
    error("loadCohort:MissingPredictors", msg, strjoin(missingCols, ", "));
end

if nargin < 2 || isempty(manifestMatFile) || ~isfile(manifestMatFile)
    error("loadCohort:MissingManifest", "cohort_manifest.mat がありません: %s", manifestMatFile);
end

sm = load(manifestMatFile);
if isfield(sm, "manifest")
    manifest = sm.manifest;
elseif isfield(sm, "idsKept")
    manifest = struct("idsKept", sm.idsKept, "idsComplete", sm.idsKept);
else
    error("loadCohort:BadManifest", "manifest がありません。");
end

if opts.useOutlierFilter
    targetIds = manifest.idsKept(:);
    idsRemoved = manifest.idsRemoved(:);
    if isempty(idsRemoved) && isfield(manifest, "idsComplete")
        idsRemoved = setdiff(manifest.idsComplete(:), targetIds);
    end
else
    if ~isfield(manifest, "idsComplete")
        error("loadCohort:BadManifest", "idsComplete がありません。");
    end
    targetIds = manifest.idsComplete(:);
    idsRemoved = [];
end

[~, ord] = sort(tbl.id);
tbl = tbl(ord, :);

keep = ismember(tbl.id, targetIds);
if nnz(keep) ~= numel(targetIds)
    missingIds = setdiff(targetIds, tbl.id(keep));
    showIds = missingIds(1:min(5, numel(missingIds)));
    error("loadCohort:MissingIds", ...
        "manifest の ID が master にありません: %s", mat2str(showIds));
end

tblAnalysis = tbl(keep, :);
[~, ordA] = sort(tblAnalysis.id);
tblAnalysis = tblAnalysis(ordA, :);

validatePredictorsFinite(tblAnalysis, predictors);

ids = tblAnalysis.id;
n = numel(ids);

X_params = tblAnalysis{:, predictors};

waveformMatrix = [];
timeGrid = [];
if isfield(s, "waveformMatrix") && ~isempty(s.waveformMatrix)
    wfIds = s.metadata.waveformIds(:);
    [found, loc] = ismember(ids, wfIds);
    waveformMatrix = nan(numel(ids), size(s.waveformMatrix, 2));
    waveformMatrix(found, :) = s.waveformMatrix(loc(found), :);
end
if isfield(s, "timeGrid")
    timeGrid = s.timeGrid;
end

cohort = struct();
cohort.ids = ids;
cohort.y = tblAnalysis.yieldPointN;
cohort.X_params = X_params;
cohort.predictorNames = predictors;
cohort.predictorTable = tblAnalysis;
cohort.X_waveform = waveformMatrix;
cohort.timeGrid = timeGrid;
cohort.n = n;
cohort.useOutlierFilter = opts.useOutlierFilter;
if isfield(manifest, "idsComplete")
    cohort.idsComplete = manifest.idsComplete(:);
    cohort.nComplete = numel(cohort.idsComplete);
else
    cohort.idsComplete = targetIds;
    cohort.nComplete = n;
end
cohort.idsRemoved = idsRemoved;
cohort.masterMatFile = string(masterMatFile);
cohort.manifestMatFile = string(manifestMatFile);
cohort.targetName = reg.targetName;

end

function validatePredictorsFinite(tbl, predictors)
predictors = string(predictors(:));
for i = 1:numel(predictors)
    p = predictors(i);
    v = tbl{:, p};
    bad = ~isfinite(v);
    if any(bad)
        badIds = tbl.id(bad);
        nShow = min(5, numel(badIds));
        error("loadCohort:NaNInKeptCohort", ...
            "固定コホート内で %s が非有限です（ID 例: %s）。outlierBasePredictors に列を追加するか master を再構築してください。", ...
            p, mat2str(badIds(1:nShow)));
    end
end
end
