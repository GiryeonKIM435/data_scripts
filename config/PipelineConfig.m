function cfg = PipelineConfig()
%PipelineConfig Pipeline paths and settings for this package.
%
% Raw data: data/; prepare products: outputs/prepare/

repoRoot = fileparts(fileparts(mfilename("fullpath")));

cfg = struct();
cfg.pipelineRoot = repoRoot;
cfg.parentDir = repoRoot;
cfg.dataDir = fullfile(repoRoot, "data");

cfg.raw.excelFile = fullfile(cfg.dataDir, "size_weight.xlsx");
cfg.raw.viscoDir = fullfile(cfg.dataDir, "visco");
cfg.raw.yieldDir = fullfile(cfg.dataDir, "yield");

cfg.out.root = fullfile(repoRoot, "outputs", "prepare");
cfg.out.load = fullfile(cfg.out.root, "01_load");
cfg.out.estimate = fullfile(cfg.out.root, "02_estimate");
cfg.out.preprocess = fullfile(cfg.out.root, "03_preprocess");
cfg.out.analyze = fullfile(cfg.out.root, "04_analyze");

cfg.paths.tomatoDataset = fullfile(cfg.out.load, "tomato_dataset.mat");
cfg.paths.noiseProfile = fullfile(cfg.out.estimate, "noise_profile.mat");
cfg.paths.tomatoFiltered = fullfile(cfg.out.estimate, "tomato_filtered.mat");
cfg.paths.tomatoWithFit = fullfile(cfg.out.estimate, "tomato_with_fit.mat");
cfg.paths.burgersFitResults = fullfile(cfg.out.estimate, "burgers_fit_results.mat");
cfg.paths.krTable = fullfile(cfg.out.estimate, "kr_table.mat");
cfg.paths.creepWaveforms = fullfile(cfg.out.estimate, "creep_waveforms.mat");
cfg.paths.estimateParamSummary = fullfile(cfg.out.estimate, "estimate_param_summary.mat");
cfg.paths.masterTable = fullfile(cfg.out.preprocess, "master_analysis_table.mat");
cfg.paths.cohortManifest = fullfile(cfg.out.preprocess, "cohort_manifest.mat");
cfg.paths.cohortParamSummary = fullfile(cfg.out.preprocess, "cohort_param_summary.mat");
cfg.paths.outlierDiagnostic = fullfile(cfg.out.preprocess, "outlier_diagnostic.mat");

reg = PredictorRegistry();
cv = CvConfig();
outlier = OutlierConfig();

cfg.predictors = reg;
cfg.cv = cv;
cfg.outlier = outlier;

cfg.detectYield.showReviewPlots = false;
cfg.detectYield.yieldGapRatioThreshold = 0.20;
cfg.detectYield.minAcceptedYieldForceN = 20;
cfg.detectYield.noiseTargetIds = [31, 46, 50];
cfg.detectYield.zeroAdjustFirstPoint = true;

cfg.burgers.saveFigures = true;
cfg.fitBurgers = burgersDefaultOpts();

cfg.figures.enabled = true;
cfg.figures.savePng = true;
cfg.figures.saveFig = true;
cfg.figures.figCompact = true;
cfg.figures.verifyFigRoundtrip = false;
cfg.figures.tilesPerPage = 12;
cfg.figures.resolution = 180;

for d = {cfg.out.root, cfg.out.load, cfg.out.estimate, cfg.out.preprocess, cfg.out.analyze}
    if ~isfolder(d{1})
        mkdir(d{1});
    end
end

end
