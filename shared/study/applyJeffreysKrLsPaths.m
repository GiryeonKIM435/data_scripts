function cfg = applyJeffreysKrLsPaths(cfg)
%applyJeffreysKrLsPaths Sensitivity: same primary mats; stiffness k via LS (not chord)
%
% Does not change prepare paths. Sets analysis tag and deploy/paper krVariant to "ls".

tag = "sens_kr_ls";
cfg.cache.cohortAnalysisTag = tag;
cfg.paper.q3AnalysisTag = tag;
cfg.q7.analysisTag = tag;
cfg.analysis.primaryAnalysisTag = tag;

cfg.deploy.krVariant = "ls";
cfg = syncPaperKrVariant(cfg);
end
