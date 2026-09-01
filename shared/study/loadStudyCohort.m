function cohort = loadStudyCohort(cfg, opts)
%loadStudyCohort master + manifest から論文検証用コホートを構築
%
% loadCohort と異なり、PredictorRegistry.paramPredictors に無い kr_* 列も読み込む。

if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = true;
end
if ~isfield(opts, "requireKrKeys")
    opts.requireKrKeys = string.empty(0, 1);
end

masterMatFile = cfg.paths.masterTable;
manifestMatFile = cfg.paths.cohortManifest;

s = load(masterMatFile, "masterTable", "metadata");
if ~isfield(s, "masterTable")
    error("loadStudyCohort:MissingMaster", "masterTable がありません。");
end
tbl = s.masterTable;

sm = load(manifestMatFile);
if isfield(sm, "manifest")
    manifest = sm.manifest;
elseif isfield(sm, "idsKept")
    manifest = struct("idsKept", sm.idsKept, "idsComplete", sm.idsKept);
else
    error("loadStudyCohort:BadManifest", "manifest がありません。");
end

if opts.useOutlierFilter
    targetIds = manifest.idsKept(:);
    idsRemoved = manifest.idsRemoved(:);
    if isempty(idsRemoved) && isfield(manifest, "idsComplete")
        idsRemoved = setdiff(manifest.idsComplete(:), targetIds);
    end
else
    targetIds = manifest.idsComplete(:);
    idsRemoved = [];
end

[~, ord] = sort(tbl.id);
tbl = tbl(ord, :);
keep = ismember(tbl.id, targetIds);
if nnz(keep) ~= numel(targetIds)
    missingIds = setdiff(targetIds, tbl.id(keep));
    error("loadStudyCohort:MissingIds", ...
        "manifest の ID が master にありません: %s", mat2str(missingIds(1:min(5, end))));
end
tblAnalysis = tbl(keep, :);
[~, ordA] = sort(tblAnalysis.id);
tblAnalysis = tblAnalysis(ordA, :);

colNames = string(tblAnalysis.Properties.VariableNames);
krCols = colNames(startsWith(colNames, "kr_") & ~startsWith(colNames, "krSuccess_") ...
    & ~startsWith(colNames, "krFit") & colNames ~= "kr");

burgersCols = cfg.burgersPredictors;
needCols = unique([cfg.targetName; burgersCols(:); krCols(:)], "stable");
missingCols = needCols(~ismember(needCols, colNames));
if ~isempty(missingCols)
    error("loadStudyCohort:MissingCols", "master に列がありません: %s", ...
        strjoin(missingCols, ", "));
end

for i = 1:numel(burgersCols)
    v = tblAnalysis{:, burgersCols(i)};
    if any(~isfinite(v))
        error("loadStudyCohort:NaNBurgers", "%s に非有限値があります。", burgersCols(i));
    end
end
if any(~isfinite(tblAnalysis.yieldPointN))
    error("loadStudyCohort:NaNYield", "yieldPointN に非有限値があります。");
end

if ~isempty(opts.requireKrKeys)
    for ki = 1:numel(opts.requireKrKeys)
        krCol = "kr_" + opts.requireKrKeys(ki);
        if ~ismember(krCol, colNames)
            error("loadStudyCohort:MissingKr", "列がありません: %s", krCol);
        end
    end
    krReqCols = "kr_" + opts.requireKrKeys(:);
    maskAllKr = true(height(tblAnalysis), 1);
    for ki = 1:numel(krReqCols)
        v = tblAnalysis{:, krReqCols(ki)};
        maskAllKr = maskAllKr & isfinite(v);
    end
    tblAnalysis = tblAnalysis(maskAllKr, :);
    if isempty(tblAnalysis)
        error("loadStudyCohort:EmptyCommonCase", "requireKrKeys の共通ケースが 0 件です。");
    end
end

cohort = struct();
cohort.ids = tblAnalysis.id;
cohort.y = tblAnalysis.yieldPointN;
cohort.predictorTable = tblAnalysis;
cohort.krCols = krCols;
cohort.krMethodKeys = extractAfter(krCols, "kr_");
cohort.burgersCols = burgersCols;
cohort.n = numel(cohort.ids);
cohort.useOutlierFilter = opts.useOutlierFilter;
cohort.idsRemoved = idsRemoved;
if isfield(manifest, "idsComplete")
    cohort.idsComplete = manifest.idsComplete(:);
    cohort.nComplete = numel(cohort.idsComplete);
else
    cohort.idsComplete = targetIds;
    cohort.nComplete = cohort.n;
end
cohort.masterMatFile = string(masterMatFile);
cohort.manifestMatFile = string(manifestMatFile);
cohort.targetName = cfg.targetName;

end
