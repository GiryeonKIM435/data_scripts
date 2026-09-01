function cfg = runOptionsToConfig(opts)
%RUNOPTIONSTOCONFIG RunOptions を PipelineConfig に反映

if nargin < 1 || isempty(opts)
    opts = defaultRunOptions();
else
    opts = mergeRunOptions(opts);
end

cfg = PipelineConfig();

cfg.figures.enabled = opts.saveFigures;
cfg.figures.savePng = opts.saveFigures;
cfg.figures.saveFig = opts.saveFigures;

cfg.burgers.saveFigures = opts.burgers.saveFigures;

cfg.detectYield.showReviewPlots = opts.detectYield.showReviewPlots;
cfg.detectYield.yieldGapRatioThreshold = opts.detectYield.yieldGapRatioThreshold;
cfg.detectYield.minAcceptedYieldForceN = opts.detectYield.minAcceptedYieldForceN;
cfg.detectYield.noiseTargetIds = opts.detectYield.noiseTargetIds;
cfg.detectYield.zeroAdjustFirstPoint = opts.detectYield.zeroAdjustFirstPoint;

cfg.cv.cvFolds = opts.cv.cvFolds;
cfg.cv.cvSeed = opts.cv.cvSeed;
cfg.cv.splitSeed = opts.cv.splitSeed;
cfg.cv.trainSeed = opts.cv.trainSeed;
cfg.cv.bootstrapSamples = opts.cv.bootstrapSamples;
cfg.cv.bootstrapSeed = opts.cv.bootstrapSeed;
cfg.cv.corrThreshold = opts.cv.corrThreshold;
cfg.cv.vifThreshold = opts.cv.vifThreshold;
cfg.cv.mlpMaxEpochsFull = opts.cv.mlpMaxEpochsFull;
cfg.cv.mlpMaxEpochsCv = opts.cv.mlpMaxEpochsCv;
cfg.cv.mlpLayerSizesParams = opts.cv.mlpLayerSizesParams;

cfg.outlier.madZThreshold = opts.outlier.madZThreshold;
cfg.outlier.mahaAlpha = opts.outlier.mahaAlpha;
cfg.outlier.modeYieldMad = opts.outlier.modeYieldMad;
cfg.outlier.modeBaseXMad = opts.outlier.modeBaseXMad;
cfg.outlier.modeRobustMaha = opts.outlier.modeRobustMaha;

cfg.runOptions = opts;
end
