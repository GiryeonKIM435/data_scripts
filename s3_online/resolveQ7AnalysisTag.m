function tag = resolveQ7AnalysisTag(cfg, opts)
%resolveQ7AnalysisTag Q7 出力・traj キャッシュ用 analysisTag

if nargin >= 2 && isstruct(opts) && isfield(opts, "analysisTag") ...
        && strlength(string(opts.analysisTag)) > 0
    tag = char(string(opts.analysisTag));
    return;
end
if isfield(cfg, "q7") && isfield(cfg.q7, "analysisTag") ...
        && strlength(string(cfg.q7.analysisTag)) > 0
    tag = char(string(cfg.q7.analysisTag));
    return;
end
tag = resolvePaperQ3AnalysisTag(cfg);
end
