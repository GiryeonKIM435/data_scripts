function trajCell = buildMethodKrTrajectories(cfg, sampleCtx, y, mdef, fitCfg, calib, ...
    yminCohortAbs, krVariant, parallelSamples, progressLabel)
%BUILDMETHODKRTRAJECTORIES 1 方式分の kr 軌跡セル配列を構築

if nargin < 8 || isempty(krVariant)
    krVariant = "chord";
end
if nargin < 9
    parallelSamples = false;
end
if nargin < 10
    progressLabel = "";
end

n = numel(y);
trajCell = cell(n, 1);
isPercentYield = string(mdef.type) == "percent_yield";
policy = resolveStreamDeployPolicy(struct(), cfg);

useParallel = false;
if parallelSamples
    poolInfo = ensurePaperStudyParallelPool(cfg);
    useParallel = poolInfo.active && n > 1;
end

tStart = tic;
if useParallel
    pool = gcp("nocreate");
    tasks = repmat(struct("fn", [], "args", {{}}, "label", "", "nOut", 1), n, 1);
    for i = 1:n
        sampleOpts = buildStreamSampleOptsLocal(isPercentYield, calib, yminCohortAbs, i, ...
            krVariant, policy);
        tasks(i).fn = @streamOneDeployKrPathTask;
        tasks(i).args = {sampleCtx{i}, y(i), mdef, fitCfg, sampleOpts};
        tasks(i).label = sprintf("i%d", i);
        tasks(i).nOut = 1;
    end
    prefix = "Q3 sample traj";
    if strlength(string(progressLabel)) > 0
        prefix = char(string(progressLabel));
    end
    results = runParallelTaskBatch(pool, tasks, struct( ...
        "prefix", prefix, ...
        "pollSeconds", 5, ...
        "tStart", tStart));
    for i = 1:n
        trajCell{i} = results{i};
    end
else
    sampleLogEvery = max(1, min(10, ceil(n / 10)));
    for i = 1:n
        sampleOpts = buildStreamSampleOptsLocal(isPercentYield, calib, yminCohortAbs, i, ...
            krVariant, policy);
        trajCell{i} = streamDeployKrPath(sampleCtx{i}, y(i), mdef, fitCfg, sampleOpts);
        if strlength(string(progressLabel)) > 0 ...
                && (i == 1 || i == n || mod(i, sampleLogEvery) == 0)
            fprintf("%s: 試料 %d/%d\n", progressLabel, i, n);
        end
    end
end

end

function krPath = streamOneDeployKrPathTask(ctx, yTrue, mdef, fitCfg, sampleOpts)
krPath = streamDeployKrPath(ctx, yTrue, mdef, fitCfg, sampleOpts);
end

function sampleOpts = buildStreamSampleOptsLocal(isPercentYield, calib, yminCohortAbs, i, ...
    krVariant, policy)
sampleOpts = struct("krVariant", krVariant);
sampleOpts.minBandPointsForKr = policy.minBandPointsForKr;
sampleOpts.percentYieldBandGatePoints = policy.percentYieldBandGatePoints;
if ~isPercentYield
    return;
end
sampleOpts.calibA = calib.a(i);
sampleOpts.calibB = calib.b(i);
sampleOpts.yminCohortAbs = yminCohortAbs;
end
