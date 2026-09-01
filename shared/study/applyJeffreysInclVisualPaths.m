function cfg = applyJeffreysInclVisualPaths(cfg)
%applyJeffreysInclVisualPaths Point cfg at visual-append sensitivity products
%
% Primary IQR complete frozen; IDs 8,71 force-appended (no re-IQR). Tag sens_incl_visual.

prepareOut = fullfile(cfg.studyRoot, "outputs", "prepare");
est = fullfile(prepareOut, "02_estimate");
pre = fullfile(prepareOut, "03_preprocess");
suf = "incl_visual";

cfg.paths.tomatoFiltered = fullfile(est, sprintf("tomato_filtered_%s.mat", suf));
cfg.paths.krTable = fullfile(est, sprintf("kr_table_%s.mat", suf));
cfg.paths.tomatoWithFit = fullfile(est, sprintf("tomato_with_fit_bi_iqr15_%s.mat", suf));
cfg.paths.jeffreysFitResults = fullfile(est, sprintf("jeffreys_fit_results_bi_iqr15_%s.mat", suf));
cfg.paths.burgersFitResults = cfg.paths.jeffreysFitResults;
cfg.paths.masterTable = fullfile(pre, sprintf("master_analysis_table_bi_iqr15_%s.mat", suf));
cfg.paths.cohortManifest = fullfile(pre, sprintf("cohort_manifest_bi_iqr15_%s.mat", suf));

cfg.paths.tomatoWithFitBiIqr15 = cfg.paths.tomatoWithFit;
cfg.paths.jeffreysFitResultsBiIqr15 = cfg.paths.jeffreysFitResults;
cfg.paths.burgersFitResultsBiIqr15 = cfg.paths.jeffreysFitResults;
cfg.paths.masterTableBiIqr15 = cfg.paths.masterTable;
cfg.paths.cohortManifestBiIqr15 = cfg.paths.cohortManifest;

tag = "sens_incl_visual";
cfg.cache.cohortAnalysisTag = tag;
cfg.paper.q3AnalysisTag = tag;
cfg.q7.analysisTag = tag;
cfg.analysis.primaryAnalysisTag = tag;
end
