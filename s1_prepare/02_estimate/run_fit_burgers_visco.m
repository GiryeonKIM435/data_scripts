function run_fit_burgers_visco(opts)
%RUN_FIT_BURGERS_VISCO Jeffreys creep identification
%
% Public entry: run_fit_jeffreys_visco.

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

if ~shouldSkipCompute(opts, cfg.paths.tomatoWithFit)
    if ~isfile(cfg.paths.tomatoFiltered)
        run_detect_yield_and_filter(opts);
    end
    s = load(cfg.paths.tomatoFiltered, "tomatoFiltered");
    [tomatoDataWithFit, fitResults, metadataTomato] = fitBurgersBatch(s.tomatoFiltered, cfg.fitBurgers);
    save(cfg.paths.tomatoWithFit, "tomatoDataWithFit", "fitResults", "metadataTomato", "-v7");
    save(cfg.paths.burgersFitResults, "fitResults", "metadataTomato", "-v7");
    fprintf("Saved: %s\n", cfg.paths.tomatoWithFit);
else
    fprintf("Existing: %s\n", cfg.paths.tomatoWithFit);
end
plotEstimateFigures(cfg, "jeffreys");
end
