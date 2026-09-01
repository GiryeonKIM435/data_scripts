function run_estimate_noise(opts)
%RUN_ESTIMATE_NOISE 共通ノイズ推定 (0-10秒区間)

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

if ~shouldSkipCompute(opts, cfg.paths.noiseProfile)
    if ~isfile(cfg.paths.tomatoDataset)
        run_build_tomato_dataset(opts);
    end
    s = load(cfg.paths.tomatoDataset, "tomatoData");
    noiseStats = estimateNoiseProfile(cfg, s.tomatoData);
    save(cfg.paths.noiseProfile, "noiseStats", "-v7");
    fprintf("保存: %s\n", cfg.paths.noiseProfile);
else
    fprintf("既存: %s\n", cfg.paths.noiseProfile);
end
plotEstimateFigures(cfg, "noise");
end