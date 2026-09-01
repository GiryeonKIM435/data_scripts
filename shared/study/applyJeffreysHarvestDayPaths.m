function cfg = applyJeffreysHarvestDayPaths(cfg, dayTag)
%applyJeffreysHarvestDayPaths Point cfg at harvest-day subset master/manifest
%
% dayTag: "0423" or "0429" (maps to analysisTag sens_harvest_0423 / sens_harvest_0429)

dayTag = string(dayTag);
if dayTag == "0423" || dayTag == "2026-04-23"
    suf = "harvest_0423";
    tag = "sens_harvest_0423";
elseif dayTag == "0429" || dayTag == "2026-04-29"
    suf = "harvest_0429";
    tag = "sens_harvest_0429";
else
    error("applyJeffreysHarvestDayPaths:BadDay", "Unsupported dayTag: %s", dayTag);
end

prepareOut = fullfile(cfg.studyRoot, "outputs", "prepare");
pre = fullfile(prepareOut, "03_preprocess");

% Keep baseline filtered / kr / fit; only master + manifest are day-restricted
cfg.paths.masterTable = fullfile(pre, sprintf("master_analysis_table_%s.mat", suf));
cfg.paths.cohortManifest = fullfile(pre, sprintf("cohort_manifest_%s.mat", suf));
cfg.paths.masterTableBiIqr15 = cfg.paths.masterTable;
cfg.paths.cohortManifestBiIqr15 = cfg.paths.cohortManifest;

cfg.cache.cohortAnalysisTag = char(tag);
cfg.paper.q3AnalysisTag = char(tag);
cfg.q7.analysisTag = char(tag);
cfg.analysis.primaryAnalysisTag = char(tag);
end
