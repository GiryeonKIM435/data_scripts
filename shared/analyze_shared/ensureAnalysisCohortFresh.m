function ensureAnalysisCohortFresh(opts)
%ensureAnalysisCohortFresh 解析前に master / manifest を Registry に合わせて更新

if nargin < 1 || isempty(opts)
    opts = defaultRunOptions();
end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

if ~isfile(cfg.paths.masterTable) || isPredictorArtifactStale(cfg.paths.masterTable)
    fprintf("ensureAnalysisCohortFresh: master を再構築（Registry 変更検知）\n");
    run_build_master_table(opts);
end

if ~isfile(cfg.paths.cohortManifest) || isPredictorArtifactStale(cfg.paths.cohortManifest, "cohort")
    fprintf("ensureAnalysisCohortFresh: cohort manifest を再構築\n");
    run_write_cohort_manifest(opts);
end

end
