function run_detect_yield_and_filter(opts)
%RUN_DETECT_YIELD_AND_FILTER 降伏点検出・品質フィルタ

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

filteredStale = isTomatoFilteredStale(cfg.paths.tomatoFiltered, cfg);
if shouldSkipCompute(opts, cfg.paths.tomatoFiltered) && ~filteredStale
    fprintf("既存: %s\n", cfg.paths.tomatoFiltered);
else
    if filteredStale && isfile(cfg.paths.tomatoFiltered)
        fprintf("零点調整設定変更検知: 降伏フィルタを再実行します -> %s\n", cfg.paths.tomatoFiltered);
    end
    if ~isfile(cfg.paths.tomatoDataset)
        run_build_tomato_dataset(opts);
    end
    if ~isfile(cfg.paths.noiseProfile)
        run_estimate_noise(opts);
    end
    sData = load(cfg.paths.tomatoDataset, "tomatoData");
    sNoise = load(cfg.paths.noiseProfile, "noiseStats");
    [tomatoFiltered, metadataFiltered] = filterTomatoByYield( ...
        sData.tomatoData, sNoise.noiseStats, cfg);
    noiseStats = sNoise.noiseStats;
    save(cfg.paths.tomatoFiltered, "tomatoFiltered", "metadataFiltered", "noiseStats", "-v7");
    fprintf("保存: %s (%d 試料)\n", cfg.paths.tomatoFiltered, numel(tomatoFiltered));
end
plotEstimateFigures(cfg, "yield");
end