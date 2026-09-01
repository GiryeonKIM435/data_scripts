function cfg = PaperStudyConfig()
%PaperStudyConfig Settings for the manuscript reproduction package.
%
% Prepare products: outputs/prepare/
% Results products: outputs/sec4_* / paper_figures / paper_tables

studyRoot = fileparts(fileparts(mfilename("fullpath")));
prepareOut = fullfile(studyRoot, "outputs", "prepare");

cfg = struct();
cfg.studyRoot = studyRoot;
cfg.pipelineRoot = studyRoot;
cfg.parentDir = studyRoot;

cfg.paths.krTable = fullfile(prepareOut, "02_estimate", "kr_table.mat");
cfg.paths.tomatoDataset = fullfile(prepareOut, "01_load", "tomato_dataset.mat");
cfg.paths.tomatoFiltered = fullfile(prepareOut, "02_estimate", "tomato_filtered.mat");
cfg.paths.creepWaveforms = fullfile(prepareOut, "02_estimate", "creep_waveforms.mat");
cfg.paths.noiseProfile = fullfile(prepareOut, "02_estimate", "noise_profile.mat");

% Manuscript Jeffreys bilateral-IQR cohort (shipped mats; do not overwrite lightly)
cfg.paths.tomatoWithFit = fullfile(prepareOut, "02_estimate", "tomato_with_fit_bi_iqr15.mat");
cfg.paths.jeffreysFitResults = fullfile(prepareOut, "02_estimate", "jeffreys_fit_results_bi_iqr15.mat");
cfg.paths.burgersFitResults = cfg.paths.jeffreysFitResults;  % legacy alias
cfg.paths.masterTable = fullfile(prepareOut, "03_preprocess", "master_analysis_table_bi_iqr15.mat");
cfg.paths.cohortManifest = fullfile(prepareOut, "03_preprocess", "cohort_manifest_bi_iqr15.mat");

cfg.paths.tomatoWithFitBiIqr15 = cfg.paths.tomatoWithFit;
cfg.paths.jeffreysFitResultsBiIqr15 = cfg.paths.jeffreysFitResults;
cfg.paths.burgersFitResultsBiIqr15 = cfg.paths.jeffreysFitResults;
cfg.paths.masterTableBiIqr15 = cfg.paths.masterTable;
cfg.paths.cohortManifestBiIqr15 = cfg.paths.cohortManifest;

cfg.out.root = fullfile(studyRoot, "outputs");
cfg.out.q0 = fullfile(cfg.out.root, "sec4_1_descriptive");
cfg.out.q1 = fullfile(cfg.out.root, "sec4_2_offline");
cfg.out.q3 = fullfile(cfg.out.root, "sec4_3_online", "alpha_fixed_deploy");
cfg.out.q5 = fullfile(cfg.out.root, "sec4_4_contribution");
cfg.out.q4 = fullfile(cfg.out.root, "misc", "q4_legacy_kr");
cfg.out.q6 = fullfile(cfg.out.root, "misc", "q6_force_deformation");
cfg.out.q7 = fullfile(cfg.out.root, "sec4_3_online");
cfg.out.q9 = fullfile(cfg.out.root, "misc", "q9_split_deploy");
cfg.out.paperTables = fullfile(cfg.out.root, "paper_tables");
cfg.out.paperFigures = fullfile(cfg.out.root, "paper_figures");
cfg.out.paperFig4All = fullfile(cfg.out.root, "sec4_3_online", "example_all_samples");
cfg.out.cache = fullfile(cfg.out.root, "shared_cache");

methods = KrMethodRegistry();
cfg.krMethodKeys = filterActiveKrMethodKeys(string({methods.key}), methods);

cfg.burgersPredictors = ["c1"; "c2"; "k2"];
cfg.sizePredictors = "d_eq";

cfg.targetName = "yieldPointN";

cfg.cv.primaryScheme = "LOOCV";
cfg.cv.kfoldFolds = 6;
cfg.cv.kfoldRepeats = 10;
cfg.cv.cvSeed = 260416;
cfg.cv.bootstrapSamples = 5000;
cfg.cv.bootstrapSeed = 260417;

cfg.analysis.useOutlierFilterPrimary = false;
cfg.analysis.runCommonCase = true;
% Absolute-force stiffness intervals (manuscript grid)
cfg.analysis.excludeKrMethodTypes = ["percent_yield"; "force_trailing"];
cfg.analysis.figureDpi = 300;
% Default output/cache tag (overridable from RUN__paper.m)
cfg.analysis.primaryAnalysisTag = "jeffreys_bi_iqr15";
cfg.krMethodKeys = filterActiveKrMethodKeys( ...
    cfg.krMethodKeys, methods, cfg.analysis.excludeKrMethodTypes);

cfg.metrics = struct();
cfg.metrics.primary = "mae";
cfg.metrics.secondary = ["rmse"; "r2"];
cfg.metrics.rankDirection = struct("mae", "ascend", "rmse", "ascend", "r2", "descend");
cfg.metrics.loocvSuffix = "_loocv";

cfg.figures.enabled = true;
cfg.figures.savePng = true;
cfg.figures.saveFig = true;  % MATLAB 上で編集できるよう .fig も保存

cfg.parallel = struct();
cfg.parallel.enabled = true;
cfg.parallel.nWorkers = 8;         % threads 併用時は 8 前後推奨（過大だと Q1 bootstrap で詰まりやすい）
cfg.parallel.poolType = "threads"; % Processes/local は RAM 増大のため非推奨
cfg.parallel.setCompThreads = true;
cfg.parallel.compThreads = 1;      % threads pool 時の BLAS スレッド（worker 数と掛け算しない）
cfg.parallel.autoStart = true;
cfg.parallel.parallelSampleCtx = true;
cfg.parallel.parallelCalibBuild = true;
cfg.parallel.parallelQ4OfflineKr = true;
cfg.parallel.parallelLoocvModels = true;
cfg.parallel.methodParallelThreshold = 8;

cfg.q1 = struct();
cfg.q1.useParfor = cfg.parallel.enabled;
cfg.q1.krVariants = string.empty(0, 1);  % 空なら cfg.deploy.krVariant のみ

cfg.deploy = struct();
cfg.deploy.alphaValues = [1.5; 2; 3];
cfg.deploy.timeOrder = "sec_asc";
cfg.deploy.stopRule = "force_ge_alpha_yhat";
cfg.deploy.primaryAlpha = 2;
cfg.deploy.krVariant = "chord";
cfg.deploy.useParfor = cfg.parallel.enabled;
cfg.deploy.parallelSamples = true;
cfg.deploy.runForceAbsFirst = true;
cfg.deploy.reuseCache = true;
cfg.deploy.saveTrajectoryCache = true;
cfg.deploy.mode = "full";
cfg.deploy.testMethodKeys = string.empty(0, 1);
cfg.deploy.testAnalysisTag = "jeffreys_bi_iqr15_test";
cfg.deploy.percentYieldBandGatePoints = 3;
cfg.deploy.minBandPointsForKr = 5;
cfg.deploy.diagnosticFailSampleIds = [75; 90; 104; 83; 40];
cfg.deploy.diagnosticTimelineSampleIds = [18; 29; 42];

cfg.cache = struct();
cfg.cache.enabled = true;
cfg.cache.cohortAnalysisTag = cfg.analysis.primaryAnalysisTag;

cfg.q5 = struct();
cfg.q5.krMethodKey = "force_s05_w30";
cfg.q5.offlineBestKrMethodKey = "force_s05_w30";
cfg.q5.onlineTrackKrMethodKey = "force_s05_w30";
cfg.q5.offlineTrackKrMethodKey = cfg.q5.offlineBestKrMethodKey;
cfg.q5.referenceCaseId = "m0_kr";
cfg.q5.foldCollinearityCaseIds = "m_all_kr_full";
cfg.q5.primaryComparisonCaseIds = [ ...
    "m_w_kr_weight"; "m_d_kr_deq"; "m_c1_kr_c1"; "m_c2_kr_c2"; ...
    "m_k2_kr_k2"; "m_b_kr_burgers"; "m_all_kr_full"];
cfg.q5.krVariant = cfg.deploy.krVariant;
cfg.q5.q3AnalysisTag = "";
cfg.q5.alphaValues = 1.4516;
cfg.q5.primaryAlpha = 1.4516;
cfg.q5.perSampleDesignAlpha = true;
cfg.q5.designAlphaGammaTag = "gamma_1p0";
cfg.q5.corrThreshold = 0.8;
cfg.q5.vifThreshold = 10;
cfg.q5.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
cfg.q5.reuseTrajectoryCache = true;
cfg.q5.onlineScatterAlpha = cfg.q5.primaryAlpha;

cfg.q4 = struct();
cfg.q4.methodKey = "legacy_t27_w54";
cfg.q4.offlineBandStartSec = 2.7;
cfg.q4.offlineBandWidthSec = 5.4;
cfg.q4.onlineWindowSec = 5.4;
cfg.q4.krVariant = "ls";
cfg.q4.analysisTag = cfg.analysis.primaryAnalysisTag;
cfg.q4.useParfor = cfg.parallel.enabled;
cfg.q4.reuseCache = true;
cfg.q4.saveTrajectoryCache = true;

cfg.q6 = struct();
cfg.q6.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
cfg.q6.analysisTag = cfg.cache.cohortAnalysisTag;
cfg.q6.reuseCache = true;
cfg.q6.forceGridMode = "min_yield";
cfg.q6.nForceGrid = 200;
cfg.q6.yieldPctGridStep = 0.5;
cfg.q6.minDefStepMm = 1e-4;
cfg.q6.binnedForceWidthsN = [1; 5];
cfg.q6.binnedMinPoints = 3;
cfg.q6.useParfor = cfg.parallel.enabled;
cfg.q6.sampleLineColor = [0.55 0.55 0.55];
cfg.q6.meanLineColor = [0 0 0];
cfg.q6.sampleLineWidth = 0.5;
cfg.q6.meanLineWidth = 2.0;

cfg.q9 = struct();
cfg.q9.switchForceN = 35;
cfg.q9.lowMethodKey = "force_s00_w20";
cfg.q9.highMethodKey = "ftrail_f30_w30";
cfg.q9.krVariant = cfg.deploy.krVariant;
cfg.q9.alphaValues = cfg.deploy.alphaValues;
cfg.q9.primaryAlpha = cfg.deploy.primaryAlpha;
cfg.q9.analysisTag = "piecewise_f35_s00w20_f30w30";
cfg.q9.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
cfg.q9.reuseCache = true;
cfg.q9.saveTrajectoryCache = true;
cfg.q9.useParfor = cfg.parallel.enabled;
cfg.q9.parallelSamples = true;
cfg.q9.doFigSamples = true;
cfg.q9.nFigSamples = 5;
cfg.q9.figSampleIds = [1; 18; 29; 42; 83];

cfg.q7 = struct();
cfg.q7.quantileP = 0.95;
cfg.q7.gammaValues = 1;  % 論文本体は alpha_design = 1 + e_p（gamma=1）のみ
cfg.q7.gamma = 1.0;      % 後方互換の既定（スイープ先頭と一致）
cfg.q7.methodTypes = "force_abs";
cfg.q7.bestSelectionMode = "minFinalUpdateMae";
cfg.q7.analysisTag = "";
cfg.q7.reuseQ3TrajTag = "";
cfg.q7.designAlphaSlice = 0;
cfg.q7.useYminStopClamp = false;
cfg.q7.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
cfg.q7.reuseCache = true;
cfg.q7.saveTrajectoryCache = true;
cfg.q7.useParfor = cfg.parallel.enabled;
cfg.q7.parallelSamples = true;

cfg.paper = struct();
cfg.paper.fontName = "Times New Roman";
cfg.paper.fontSizeBase = 10.5;
cfg.paper.fontSizeLegend = 8;
cfg.paper.fontSizeTitle = 11;
cfg.paper.fontSizeSubtitle = 9.5;
cfg.paper.tableDecimals = 1;
% 4.2/4.3 MAE ヒートマップの固定色尺度 [N]（offline abs / online abs 共有）
cfg.paper.maeHeatmapClim = [9.5, 20];
cfg.paper.offlineKrMethodKey = "force_s05_w30";
cfg.paper.offlineKrVariant = cfg.deploy.krVariant;
cfg.paper.exampleSampleId = 1;
cfg.paper.exampleMethodKey = "force_s05_w30";
cfg.paper.exampleMethodKeysByType = struct( ...
    "force_abs", "force_s05_w30");
cfg.paper.exampleAlpha = cfg.deploy.primaryAlpha;
cfg.paper.q3AnalysisTag = "";
cfg.paper.doFig4AllSamples = false;
cfg.paper.harvestBatchAMaxId = 50;  % id<=50 → 2026-04-23 (raw visco dates), else → 2026-04-29

% Sensitivity prepare aliases (do not overwrite manuscript bi_iqr15 mats)
cfg.paths.tomatoWithFitNoIqr = fullfile(prepareOut, "02_estimate", "tomato_with_fit_no_iqr.mat");
cfg.paths.jeffreysFitResultsNoIqr = fullfile(prepareOut, "02_estimate", "jeffreys_fit_results_no_iqr.mat");
cfg.paths.masterTableNoIqr = fullfile(prepareOut, "03_preprocess", "master_analysis_table_no_iqr.mat");
cfg.paths.cohortManifestNoIqr = fullfile(prepareOut, "03_preprocess", "cohort_manifest_no_iqr.mat");

cfg.out.sensitivity = fullfile(cfg.out.root, "sec4_sensitivity");
for d = {cfg.out.root, cfg.out.q0, cfg.out.q1, cfg.out.q5, cfg.out.q7, ...
        cfg.out.paperTables, cfg.out.paperFigures, cfg.out.cache, cfg.out.sensitivity}
    if ~isfolder(d{1})
        mkdir(d{1});
    end
end

end
