function [summaryTable, metadata, sampleTable] = buildCohortParamSummary(analysisTable, cfg)
%BUILDCOHORTPARAMSUMMARY 外れ値除去後コホートの平均・標準偏差要約

if nargin < 2 || isempty(cfg)
    cfg = PipelineConfig();
end

reg = PredictorRegistry();
catalog = cohortParamCatalog(reg);
sampleTable = analysisTable;

nCat = height(catalog);
category = strings(nCat, 1);
parameter = strings(nCat, 1);
unit = strings(nCat, 1);
nValid = zeros(nCat, 1);
meanVal = nan(nCat, 1);
stdVal = nan(nCat, 1);
minVal = nan(nCat, 1);
maxVal = nan(nCat, 1);

colNames = string(analysisTable.Properties.VariableNames);
for i = 1:nCat
    name = catalog.parameter(i);
    category(i) = catalog.category(i);
    parameter(i) = name;
    unit(i) = catalog.unit(i);
    if ~ismember(name, colNames)
        continue;
    end
    v = analysisTable{:, name};
    mask = isfinite(v);
    nValid(i) = nnz(mask);
    if nValid(i) == 0
        continue;
    end
    vv = v(mask);
    meanVal(i) = mean(vv);
    stdVal(i) = std(vv, 0);
    minVal(i) = min(vv);
    maxVal(i) = max(vv);
end

summaryTable = table(category, parameter, unit, nValid, meanVal, stdVal, minVal, maxVal, ...
    'VariableNames', {'category', 'parameter', 'unit', 'n', 'mean', 'std', 'min', 'max'});

metadata = struct();
metadata.createdAt = datetime("now");
metadata.cohort = "outlier_filtered";
metadata.nKept = height(analysisTable);
metadata.nRemoved = NaN;
metadata.predictors = reg.paramPredictors;
metadata.targetName = reg.targetName;
metadata.sourceFiles = struct( ...
    "masterTable", string(cfg.paths.masterTable), ...
    "cohortManifest", string(cfg.paths.cohortManifest));

end

function catalog = cohortParamCatalog(reg)
params = [string(reg.targetName); reg.paramPredictors(:)];
category = strings(numel(params), 1);
unit = strings(numel(params), 1);

unitMap = struct( ...
    "weight", "g", "x", "mm", "y", "mm", "z", "mm", ...
    "yieldPointN", "N", ...
    "k2", "N/mm", "c1", "N·s/mm", "c2", "N·s/mm", ...
    "t50", "s", "t95", "s", "vInit", "mm/s", "vLong", "mm/s", ...
    "delayedRatio", "-");

for i = 1:numel(params)
    name = params(i);
    if name == reg.targetName
        category(i) = "yield";
        unit(i) = "N";
    elseif startsWith(name, "kr_")
        category(i) = "kr";
        unit(i) = "N/mm";
    elseif isfield(unitMap, name)
        category(i) = categorizeNonKr(name);
        unit(i) = unitMap.(char(name));
    else
        category(i) = "other";
        unit(i) = "";
    end
end

catalog = table(category, params, unit, 'VariableNames', {'category', 'parameter', 'unit'});
end

function cat = categorizeNonKr(name)
if ismember(name, ["weight", "x", "y", "z"])
    cat = "measurement";
elseif ismember(name, ["t50", "t95", "vInit", "vLong", "delayedRatio"])
    cat = "creep";
else
    cat = "burgers";
end
end
