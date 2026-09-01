function [keys, meta] = resolveDeployMethodKeys(cfg, opts)
%resolveDeployMethodKeys Q3 で評価する kr 方式一覧を決定（full / test）

if nargin < 2 || isempty(opts)
    opts = struct();
end

meta = struct();
meta.mode = resolveDeployMode(cfg, opts);
meta.source = "";

if isfield(opts, "methodKeys") && ~isempty(opts.methodKeys)
    keys = string(opts.methodKeys(:));
    meta.source = "opts.methodKeys";
    keys = validateMethodKeys(keys, cfg);
    return;
end

if strcmpi(meta.mode, "full")
    keys = cfg.krMethodKeys(:);
    meta.source = "cfg.krMethodKeys";
    return;
end

if isfield(cfg.deploy, "testMethodKeys") && ~isempty(cfg.deploy.testMethodKeys)
    keys = string(cfg.deploy.testMethodKeys(:));
    meta.source = "cfg.deploy.testMethodKeys";
    keys = validateMethodKeys(keys, cfg);
    return;
end

q1Results = [];
if isfield(opts, "q1Results")
    q1Results = opts.q1Results;
end
keys = pickQ1TestMethodKeys(q1Results, cfg);
meta.source = "q1_auto";

end

function mode = resolveDeployMode(cfg, opts)
mode = "full";
if isfield(cfg.deploy, "mode") && strlength(string(cfg.deploy.mode)) > 0
    mode = char(string(cfg.deploy.mode));
end
if isfield(opts, "mode") && strlength(string(opts.mode)) > 0
    mode = char(string(opts.mode));
end
end

function keys = pickQ1TestMethodKeys(q1Results, cfg)
defaults = defaultTestMethodKeys(cfg);
krVariant = string(cfg.deploy.krVariant);

if isempty(q1Results) || ~isfield(q1Results, "summaryTable")
    warning("resolveDeployMethodKeys:NoQ1", ...
        "Q1 結果が無いため既定の 3 方式を使用: %s", strjoin(defaults, ", "));
    keys = appendPaperPctMethodKey(defaults, cfg);
    keys = validateMethodKeys(keys, cfg);
    return;
end

tbl = q1Results.summaryTable;
if ismember("variant", tbl.Properties.VariableNames)
    rankRows = tbl(string(tbl.variant) == krVariant, :);
else
    rankRows = tbl;
end
if isempty(rankRows)
    rankRows = tbl;
end
rankRows = sortrows(rankRows, "mae_loocv", "ascend", "MissingPlacement", "last");

picked = strings(0, 1);
if ~isempty(rankRows)
    picked(end + 1, 1) = string(rankRows.krMethodKey(1)); %#ok<AGROW>
end

fa = rankRows(string(rankRows.methodType) == "force_abs", :);
if ~isempty(fa)
    picked(end + 1, 1) = string(fa.krMethodKey(1)); %#ok<AGROW>
end

if includesPercentYield(cfg)
    py = rankRows(string(rankRows.methodType) == "percent_yield", :);
    if ~isempty(py)
        picked(end + 1, 1) = string(py.krMethodKey(1)); %#ok<AGROW>
    end
else
    ft = rankRows(string(rankRows.methodType) == "force_trailing", :);
    if ~isempty(ft)
        picked(end + 1, 1) = string(ft.krMethodKey(1)); %#ok<AGROW>
    end
end

picked = unique(picked, "stable");
if numel(picked) < 3
    extras = defaults(~ismember(defaults, picked));
    need = min(3 - numel(picked), numel(extras));
    picked = [picked; extras(1:need)]; %#ok<AGROW>
end
keys = picked(1:min(3, numel(picked)));
keys = appendPaperPctMethodKey(keys, cfg);
keys = validateMethodKeys(keys, cfg);

end

function defaults = defaultTestMethodKeys(cfg)
if includesPercentYield(cfg)
    defaults = ["force_s00_w10"; "force_s05_w10"; "pct_s00_w10"];
else
    defaults = ["force_s00_w10"; "force_s05_w10"; "ftrail_f05_w05"];
end
defaults = defaults(ismember(defaults, string(cfg.krMethodKeys(:))));
end

function keys = appendPaperPctMethodKey(keys, cfg)
if ~includesPercentYield(cfg)
    return;
end
paperPctKey = "pct_s25_w50";
if ~ismember(paperPctKey, keys) && ismember(paperPctKey, string(cfg.krMethodKeys(:)))
    keys = [keys; paperPctKey]; %#ok<AGROW>
end
end

function tf = includesPercentYield(cfg)
tf = ismember("percent_yield", activeKrMethodTypes(cfg));
end

function keys = validateMethodKeys(keys, cfg)
keys = string(keys(:));
allKeys = string(cfg.krMethodKeys(:));
missing = keys(~ismember(keys, allKeys));
if ~isempty(missing)
    error("resolveDeployMethodKeys:UnknownMethod", ...
        "未知の kr 方式: %s", strjoin(missing, ", "));
end

end
