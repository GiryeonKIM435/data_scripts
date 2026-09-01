function run_build_tomato_dataset(opts)
%RUN_BUILD_TOMATO_DATASET 生データ統合 (Excel + visco + yield)

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

if shouldSkipCompute(opts, cfg.paths.tomatoDataset)
    fprintf("既存: %s\n", cfg.paths.tomatoDataset);
    return;
end

[tomatoData, metadata] = buildTomatoDataset(cfg);
save(cfg.paths.tomatoDataset, "tomatoData", "metadata", "-v7");
fprintf("保存: %s (%d 試料)\n", cfg.paths.tomatoDataset, numel(tomatoData));
end