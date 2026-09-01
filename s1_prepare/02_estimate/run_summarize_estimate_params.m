function run_summarize_estimate_params(opts)
%RUN_SUMMARIZE_ESTIMATE_PARAMS 推定パラメータの平均・標準偏差を表と図で出力

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

if shouldSkipCompute(opts, cfg.paths.estimateParamSummary)
    fprintf("既存: %s\n", cfg.paths.estimateParamSummary);
    if cfg.figures.enabled && isfile(cfg.paths.estimateParamSummary)
        s = load(cfg.paths.estimateParamSummary, "summaryTable", "metadata");
        plotEstimateParamSummary(cfg, s.summaryTable, s.metadata);
    end
    return;
end

if ~isfile(cfg.paths.tomatoWithFit)
    run_fit_burgers_visco(opts);
end
if ~isfile(cfg.paths.krTable)
    run_estimate_kr(opts);
end

[summaryTable, metadata, sampleTable] = buildEstimateParamSummary(cfg);

summaryCsv = strrep(char(cfg.paths.estimateParamSummary), ".mat", ".csv");
writetable(summaryTable, char(summaryCsv));
save(cfg.paths.estimateParamSummary, "summaryTable", "metadata", "sampleTable", "-v7");

fprintf("推定パラメータ要約: %d 試料, %d パラメータ -> %s\n", ...
    metadata.nBurgersSuccess, height(summaryTable), cfg.paths.estimateParamSummary);

plotEstimateParamSummary(cfg, summaryTable, metadata);
end
