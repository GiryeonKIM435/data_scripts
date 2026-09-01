function tag = resolveQ7TrajCacheTag(cfg, analysisTag, opts)
%resolveQ7TrajCacheTag Q3 traj 再利用先（shared_cache/<tag>/traj）

if nargin >= 3 && isstruct(opts) && isfield(opts, "q3AnalysisTag") ...
        && strlength(string(opts.q3AnalysisTag)) > 0
    tag = char(string(opts.q3AnalysisTag));
    return;
end
if isfield(cfg, "q7") && isfield(cfg.q7, "reuseQ3TrajTag") ...
        && strlength(string(cfg.q7.reuseQ3TrajTag)) > 0
    tag = char(string(cfg.q7.reuseQ3TrajTag));
    return;
end
tag = char(string(analysisTag));
end
