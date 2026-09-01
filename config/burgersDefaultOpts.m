function opts = burgersDefaultOpts()
%BURGERSDEFAULTOPTS Jeffreys identification defaults

opts = struct();
opts.minPoints = 300;
opts.maxPointsForFit = 3000;
opts.smoothWindowSec = 0.20;
opts.minSmoothPoints = 5;
opts.targetSpeedMmPerMin = 20.0;
opts.contactStartSustainSec = 0.12;
opts.creepHoldDurationSec = 150;
opts.recoverySearchStartRatio = 0.40;
opts.holdMeanWindowSec = 5.0;
opts.recoveryRangeRatio = [0.99, 1.00];
opts.effectiveDropAlpha = 0.80;
opts.recoveryStrongSmoothSec = 0.01;
opts.significanceSigmaScale = 3.0;
opts.minSignificantDropSec = 0.1;
opts.refinedCreepEndSpeedThrMmPerMin = -10.0;
opts.refinedCreepEndLookBackSec = 8.0;
opts.refinedCreepEndLookAheadSec = 3.0;
opts.creepLoadGram = 300;
opts.fitNumStarts = 5;
opts.fitInitLogJitterStd = 0.35;
% Multi-start uses randn; fix seed so prepare→offline is reproducible across runs.
opts.fitRngSeed = 260416;
opts.fitUseRobustLoss = true;
opts.fitRobustDelta = 1.5;
opts.rejectParamOutliers = false;
opts.outlierIqrMultiplier = 2.0;
opts.outlierMinSuccessCount = 12;
opts.useParallel = false;
end
