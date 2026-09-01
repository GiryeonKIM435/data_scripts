function key = resolvePaperExampleKrKey(cfg, q1Source)
%resolvePaperExampleKrKey 論文 fig2 用の代表 kr 方式キーを決宁E
%
% pct 除外時は Q1 の force_abs 最良 MAE を優先。見つからなければ cfg 既定にフォールバック、E

key = "";
if nargin >= 1 && isfield(cfg, "paper") && isfield(cfg.paper, "offlineKrMethodKey")
    key = string(cfg.paper.offlineKrMethodKey);
    if strlength(key) > 0 && isKrMethodKeyActive(key, cfg)
        return;
    end
end

tbl = resolveQ1SummaryTable(q1Source, cfg);
krVariant = string(cfg.deploy.krVariant);

if ~isempty(tbl)
    sub = tbl;
    if ismember("variant", sub.Properties.VariableNames)
        sub = sub(string(sub.variant) == krVariant, :);
    end
    if isempty(sub)
        sub = tbl;
    end
    fa = sub(string(sub.methodType) == "force_abs", :);
    if ~isempty(fa) && ismember("mae_loocv", fa.Properties.VariableNames)
        fa = sortrows(fa, "mae_loocv", "ascend", "MissingPlacement", "last");
        key = string(fa.krMethodKey(1));
        if isKrMethodKeyActive(key, cfg)
            return;
        end
    end
end

key = fallbackPaperExampleKrKey(cfg);

end

function tbl = resolveQ1SummaryTable(q1Source, cfg)
tbl = [];
if nargin < 1 || isempty(q1Source)
    q1Source = [];
end

if isstruct(q1Source) && isfield(q1Source, "summaryTable")
    tbl = q1Source.summaryTable;
    return;
end
if istable(q1Source)
    tbl = q1Source;
    return;
end

if nargin < 2 || isempty(cfg)
    return;
end
tag = "burgers_iqr2";
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
    tag = char(string(cfg.cache.cohortAnalysisTag));
end
try
    tbl = loadQ1SummaryTable(cfg, tag);
catch
    tbl = [];
end

end

function key = fallbackPaperExampleKrKey(cfg)
key = "force_s05_w05";
if nargin >= 1 && isfield(cfg, "paper") && isfield(cfg.paper, "exampleMethodKeysByType")
    byType = cfg.paper.exampleMethodKeysByType;
    if isstruct(byType) && isfield(byType, "force_abs")
        candidate = string(byType.force_abs);
        if strlength(candidate) > 0
            key = candidate;
        end
    end
end
key = string(key);
if nargin >= 1 && ~isKrMethodKeyActive(key, cfg)
    active = string(cfg.krMethodKeys(:));
    faKeys = active(startsWith(active, "force_"));
    if ~isempty(faKeys)
        key = faKeys(1);
    elseif ~isempty(active)
        key = active(1);
    end
end

end

function ok = isKrMethodKeyActive(key, cfg)
ok = false;
if nargin < 2 || ~isfield(cfg, "krMethodKeys")
    return;
end
ok = ismember(string(key), string(cfg.krMethodKeys(:)));

end
