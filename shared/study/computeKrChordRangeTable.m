function T = computeKrChordRangeTable(cfg, cohort)
%computeKrChordRangeTable Chord stiffness k range on absolute-force intervals
%
% Returns min/max/mean/std over the manuscript force_abs grid.

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(cohort)
    cohort = loadStudyCohort(cfg, struct("useOutlierFilter", false));
end

tbl = cohort.predictorTable;
methods = KrMethodRegistry();
keys = string(cfg.krMethodKeys(:));
if isempty(keys)
    keys = filterActiveKrMethodKeys(string({methods.key}), methods, ...
        ["percent_yield"; "force_trailing"]);
end

krVariant = "chord";
if isfield(cfg, "deploy") && isfield(cfg.deploy, "krVariant") ...
        && strlength(string(cfg.deploy.krVariant)) > 0
    krVariant = string(cfg.deploy.krVariant);
end

vals = [];
nMethods = 0;
for i = 1:numel(keys)
    key = keys(i);
    m = lookupKrMethodRegistry(key, methods);
    if string(m.type) ~= "force_abs"
        continue;
    end
    krCol = resolveDeployKrColumn(tbl, key, krVariant);
    if ~ismember(krCol, tbl.Properties.VariableNames)
        warning("computeKrChordRangeTable:MissingCol", ...
            "Missing column %s; skipped.", krCol);
        continue;
    end
    v = tbl.(krCol);
    v = v(isfinite(v) & v > 0);
    if isempty(v)
        continue;
    end
    vals = [vals; v(:)]; %#ok<AGROW>
    nMethods = nMethods + 1;
end

if isempty(vals)
    k_min = nan; k_max = nan; k_mean = nan; k_std = nan;
    nValues = 0;
else
    k_min = min(vals); k_max = max(vals);
    k_mean = mean(vals); k_std = std(vals, 0);
    nValues = numel(vals);
end

T = table( ...
    "force_abs", ...
    "Absolute-force intervals", ...
    nMethods, nValues, k_min, k_max, k_mean, k_std, ...
    'VariableNames', {'scope', 'label', 'nMethods', 'nValues', ...
    'k_min', 'k_max', 'k_mean', 'k_std'});
end
