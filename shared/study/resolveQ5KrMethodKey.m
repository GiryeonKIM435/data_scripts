function [key, source] = resolveQ5KrMethodKey(cfg, opts)
%resolveQ5KrMethodKey Q5 固定 kr 方式（cfg 優先、未指定時 Q3 overall best）

if nargin < 2
    opts = struct();
end

if isfield(cfg, "q5") && isfield(cfg.q5, "krMethodKey") ...
        && strlength(string(cfg.q5.krMethodKey)) > 0
    key = string(cfg.q5.krMethodKey);
    source = "cfg.q5.krMethodKey";
    return;
end

if nargin >= 2 && isfield(opts, "krMethodKey") && strlength(string(opts.krMethodKey)) > 0
    key = string(opts.krMethodKey);
    source = "opts.krMethodKey";
    return;
end

q3Tag = resolveQ5Q3AnalysisTag(cfg, opts);
primaryAlpha = cfg.deploy.primaryAlpha;
if isfield(cfg, "q5") && isfield(cfg.q5, "primaryAlpha")
    primaryAlpha = cfg.q5.primaryAlpha;
end

csvPath = fullfile(cfg.out.q3, q3Tag, "streaming_deploy_best_by_alpha.csv");
if ~isfile(csvPath)
    error("resolveQ5KrMethodKey:NoQ3", ...
        "Q3 ベスト CSV がありません: %s（先に Q3 を実行するか cfg.q5.krMethodKey を指定）", csvPath);
end

bb = readtable(csvPath);
bb = bb(abs(bb.alpha - primaryAlpha) < 1e-9 & string(bb.scope) == "overall", :);
if isempty(bb) || strlength(string(bb.krMethodKey(1))) == 0
    error("resolveQ5KrMethodKey:NoBest", ...
        "Q3 overall best @alpha=%.1f が見つかりません: %s", primaryAlpha, csvPath);
end

key = string(bb.krMethodKey(1));
source = sprintf("Q3 overall @alpha=%.1f", primaryAlpha);

end

function tag = resolveQ5Q3AnalysisTag(cfg, opts)
if nargin >= 2 && isfield(opts, "q3AnalysisTag") && strlength(string(opts.q3AnalysisTag)) > 0
    tag = char(string(opts.q3AnalysisTag));
    return;
end
if isfield(cfg, "q5") && isfield(cfg.q5, "q3AnalysisTag") ...
        && strlength(string(cfg.q5.q3AnalysisTag)) > 0
    tag = char(string(cfg.q5.q3AnalysisTag));
    return;
end
tag = resolvePaperQ3AnalysisTag(cfg);
end
