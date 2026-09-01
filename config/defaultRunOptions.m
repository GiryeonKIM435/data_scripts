function opts = defaultRunOptions()
%DEFAULTRUNOPTIONS Run File / RUN_pipeline 用の既定パラメータ

opts = struct();

% --- 共通 ---
opts.skipIfExists = true;
opts.forceRecompute = false;
opts.saveFigures = true;

% --- 解析 ---
opts.analyze = struct();
opts.analyze.useOutlierFilter = true;
opts.analyze.runCorrelation = true;
opts.analyze.runKrRegression = true;
opts.analyze.runOls = true;
opts.analyze.runLasso = true;
opts.analyze.runRf = true;
opts.analyze.runPca = true;
opts.analyze.runMlp = true;
opts.analyze.runCompareMethods = true;

% --- CV ---
opts.cv = struct();
opts.cv.cvFolds = 6;
opts.cv.cvSeed = 260416;
opts.cv.splitSeed = 26041600;
opts.cv.trainSeed = 26041601;
opts.cv.bootstrapSamples = 5000;
opts.cv.bootstrapSeed = 42;
opts.cv.corrThreshold = 0.90;
opts.cv.vifThreshold = 10;
opts.cv.mlpMaxEpochsFull = 200;
opts.cv.mlpMaxEpochsCv = 80;
opts.cv.mlpLayerSizesParams = [8, 4];

% --- 外れ値 ---
opts.outlier = struct();
opts.outlier.madZThreshold = 3.5;
opts.outlier.mahaAlpha = 0.975;
opts.outlier.modeYieldMad = true;
opts.outlier.modeBaseXMad = true;
opts.outlier.modeRobustMaha = false;

% --- 降伏検出 ---
opts.detectYield = struct();
opts.detectYield.showReviewPlots = false;
opts.detectYield.yieldGapRatioThreshold = 0.20;
opts.detectYield.minAcceptedYieldForceN = 20;
opts.detectYield.noiseTargetIds = [31, 46, 50];
opts.detectYield.zeroAdjustFirstPoint = true;

% --- Jeffreys fit ---
opts.burgers = struct();
opts.burgers.saveFigures = true;

end
