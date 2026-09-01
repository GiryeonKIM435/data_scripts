function run_extract_creep_waveform(opts)
%RUN_EXTRACT_CREEP_WAVEFORM fit 結果の creep 区間を 2048 点で保存

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);
reg = PredictorRegistry();
nPoints = reg.waveformNPoints;

if ~shouldSkipCompute(opts, cfg.paths.creepWaveforms)
    if ~isfile(cfg.paths.tomatoWithFit)
        run_fit_burgers_visco(opts);
    end
    s = load(cfg.paths.tomatoWithFit, "fitResults");
    [waveformMatrix, waveformIds, timeGrid, metadata] = ...
        extractCreepFromFitResults(s.fitResults, nPoints);
    save(cfg.paths.creepWaveforms, ...
        "waveformMatrix", "waveformIds", "timeGrid", "metadata", "-v7");
    fprintf("保存: %s\n", cfg.paths.creepWaveforms);
else
    fprintf("既存: %s\n", cfg.paths.creepWaveforms);
end
plotEstimateFigures(cfg, "creep");
end