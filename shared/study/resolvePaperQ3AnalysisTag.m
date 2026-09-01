function tag = resolvePaperQ3AnalysisTag(cfg)
%resolvePaperQ3AnalysisTag Q3 / 論文既定 analysisTag

if isfield(cfg, "paper") && isfield(cfg.paper, "q3AnalysisTag") ...
        && strlength(string(cfg.paper.q3AnalysisTag)) > 0
    tag = char(string(cfg.paper.q3AnalysisTag));
    return;
end
if isfield(cfg, "analysis") && isfield(cfg.analysis, "primaryAnalysisTag") ...
        && strlength(string(cfg.analysis.primaryAnalysisTag)) > 0
    tag = char(string(cfg.analysis.primaryAnalysisTag));
    return;
end
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag") ...
        && strlength(string(cfg.cache.cohortAnalysisTag)) > 0
    tag = char(string(cfg.cache.cohortAnalysisTag));
    return;
end
tag = "jeffreys_bi_iqr15";
end
