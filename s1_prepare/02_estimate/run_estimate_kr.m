function run_estimate_kr(opts)
%RUN_ESTIMATE_KR kr 推定（KrMethodRegistry の全方式）

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

krStale = isKrArtifactStale(cfg.paths.krTable);
if shouldSkipCompute(opts, cfg.paths.krTable) && ~krStale
    fprintf("既存: %s\n", cfg.paths.krTable);
else
    if krStale && isfile(cfg.paths.krTable)
        fprintf("KrMethodRegistry 変更検知: kr を再推定します -> %s\n", cfg.paths.krTable);
    end
    reuseFrom = [];
    if krStale && isfile(cfg.paths.krTable)
        sOld = load(cfg.paths.krTable, "krExport", "metadata");
        if isfield(sOld, "krExport")
            reuseFrom = struct("krExport", sOld.krExport);
            if isfield(sOld, "metadata")
                reuseFrom.metadata = sOld.metadata;
            end
        end
    end
    if ~isfile(cfg.paths.tomatoFiltered)
        run_detect_yield_and_filter(opts);
    end
    if ~isfile(cfg.paths.tomatoDataset)
        run_build_tomato_dataset(opts);
    end
    if ~isfile(cfg.paths.noiseProfile)
        run_estimate_noise(opts);
    end
    sFilt = load(cfg.paths.tomatoFiltered, "tomatoFiltered");
    sRaw = load(cfg.paths.tomatoDataset, "tomatoData");
    sNoise = load(cfg.paths.noiseProfile, "noiseStats");
    [krExport, metadata] = estimateKrTable( ...
        sFilt.tomatoFiltered, sRaw.tomatoData, sNoise.noiseStats, cfg, reuseFrom);
    krTable = krExport;
    save(cfg.paths.krTable, "krTable", "krExport", "metadata", "-v7");
    fprintf("保存: %s\n", cfg.paths.krTable);
end
plotEstimateFigures(cfg, "kr");
end
