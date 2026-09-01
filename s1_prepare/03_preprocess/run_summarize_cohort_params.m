function run_summarize_cohort_params(opts)
%RUN_SUMMARIZE_COHORT_PARAMS 外れ値除去後コホートの平均・SD を表と図で出力

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

if shouldSkipCompute(opts, cfg.paths.cohortParamSummary, true)
    fprintf("既存: %s\n", cfg.paths.cohortParamSummary);
    if cfg.figures.enabled && isfile(cfg.paths.cohortParamSummary)
        s = load(cfg.paths.cohortParamSummary, "summaryTable", "metadata");
        plotCohortParamSummary(cfg, s.summaryTable, s.metadata);
    end
    return;
end

if ~isfile(cfg.paths.cohortManifest) || isPredictorArtifactStale(cfg.paths.cohortManifest, "cohort")
    run_write_cohort_manifest(opts);
end
if ~isfile(cfg.paths.masterTable) || isPredictorArtifactStale(cfg.paths.masterTable)
    run_build_master_table(opts);
end

sM = load(cfg.paths.masterTable, "masterTable");
sC = load(cfg.paths.cohortManifest, "manifest");
manifest = sC.manifest;
tbl = sM.masterTable;
keep = ismember(tbl.id, manifest.idsKept);
analysisTable = tbl(keep, :);
[~, ord] = sort(analysisTable.id);
analysisTable = analysisTable(ord, :);

[summaryTable, metadata, sampleTable] = buildCohortParamSummary(analysisTable, cfg);
metadata.nRemoved = manifest.nRemoved;
metadata.idsKept = manifest.idsKept;
metadata.idsRemoved = manifest.idsRemoved;
metadata.outlierCfg = manifest.outlierCfg;

summaryCsv = strrep(char(cfg.paths.cohortParamSummary), ".mat", ".csv");
writetable(summaryTable, char(summaryCsv));
save(cfg.paths.cohortParamSummary, "summaryTable", "metadata", "sampleTable", "-v7");

fprintf("コホートパラメータ要約: kept=%d, %d パラメータ -> %s\n", ...
    metadata.nKept, height(summaryTable), cfg.paths.cohortParamSummary);

plotCohortParamSummary(cfg, summaryTable, metadata);
end
