function cfg = applyJeffreysNoIqrPaths(cfg)
%applyJeffreysNoIqrPaths Point cfg.paths at Jeffreys IQR-off sensitivity products

if ~isfield(cfg, "paths") || ~isfield(cfg.paths, "tomatoWithFitNoIqr")
    error("applyJeffreysNoIqrPaths:MissingPaths", ...
        "PaperStudyConfig missing tomatoWithFitNoIqr (and related) paths.");
end

cfg.paths.tomatoWithFit = cfg.paths.tomatoWithFitNoIqr;
cfg.paths.jeffreysFitResults = cfg.paths.jeffreysFitResultsNoIqr;
cfg.paths.burgersFitResults = cfg.paths.jeffreysFitResultsNoIqr;
cfg.paths.masterTable = cfg.paths.masterTableNoIqr;
cfg.paths.cohortManifest = cfg.paths.cohortManifestNoIqr;

tag = "sens_no_iqr";
cfg.cache.cohortAnalysisTag = tag;
cfg.paper.q3AnalysisTag = tag;
cfg.q7.analysisTag = tag;
cfg.analysis.primaryAnalysisTag = tag;
end
