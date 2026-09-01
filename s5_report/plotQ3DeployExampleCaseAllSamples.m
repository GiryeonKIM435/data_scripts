function summary = plotQ3DeployExampleCaseAllSamples(cfg, cohort, outDir)
%plotQ3DeployExampleCaseAllSamples 全試料×方式種別の fig4 力–時間図

if nargin < 3 || isempty(outDir)
    outDir = cfg.out.paperFig4All;
end
if ~isfolder(outDir)
    mkdir(outDir);
end

alphaValues = cfg.deploy.alphaValues(:);
methodTypes = activeKrMethodTypes();
prefixByType = struct( ...
    "percent_yield", "yield_pct", ...
    "force_abs", "force_abs", ...
    "force_trailing", "force_trail");
keysByType = resolveExampleMethodKeysByType(cfg);
figOpts = struct("showLegend", false);

methods = KrMethodRegistry();
[sampleCtx, fitCfg, ~] = loadQ4DeploySampleCtx(cfg, cohort);
yminCohortAbs = computeCohortYieldMin(cohort.y);

nSamples = cohort.n;
nTypes = numel(methodTypes);
summary = struct();
summary.outDir = outDir;
summary.nSamples = nSamples;
summary.nTypes = nTypes;
summary.outPaths = strings(nSamples * nTypes, 1);
summary.nWritten = 0;
pathPtr = 0;

fprintf("fig4 all-samples: n=%d × %d types → %s\n", nSamples, nTypes, outDir);

for si = 1:nSamples
    sampleId = cohort.ids(si);
    ctx = sampleCtx{si};
    yTrue = cohort.y(si);

    for ti = 1:nTypes
        mt = methodTypes(ti);
        methodKey = keysByType.(char(mt));
        prefix = prefixByType.(char(mt));
        mdef = lookupKrMethodRegistry(methodKey, methods);
        calib = resolveDeployCalibForPaperFigure(cfg, cohort, methodKey);

        sampleOpts = struct();
        policy = resolveStreamDeployPolicy(sampleOpts, cfg);
        sampleOpts.minBandPointsForKr = policy.minBandPointsForKr;
        sampleOpts.percentYieldBandGatePoints = policy.percentYieldBandGatePoints;
        if string(mdef.type) == "percent_yield"
            sampleOpts.calibA = calib.a(si);
            sampleOpts.calibB = calib.b(si);
            sampleOpts.yminCohortAbs = yminCohortAbs;
        end

        krPath = streamDeployKrPath(ctx, yTrue, mdef, fitCfg, sampleOpts);
        traj = applyDeployCalibToTrajectory(krPath, yTrue, calib.a(si), calib.b(si));

        tStopVec = nan(numel(alphaValues), 1);
        for ai = 1:numel(alphaValues)
            outcome = evalStopAlphas(traj, alphaValues(ai), yTrue);
            tStopVec(ai) = outcome.t_stop;
        end

        if isfield(traj, "forceAbs")
            forceAbs = traj.forceAbs(:);
        elseif isfield(ctx, "forceOffsetN") && isfinite(ctx.forceOffsetN)
            forceAbs = traj.force(:) + ctx.forceOffsetN;
        else
            forceAbs = traj.force(:);
        end

        outPath = fullfile(outDir, sprintf("fig4_q3_deploy_example_%s_id%03d.png", prefix, sampleId));
        titleStr = sprintf("Q3 deploy (id=%d, %s)", sampleId, mdef.label);
        plotQ3DeployForceTimeMultiAlphaFigure(ctx.sec(:), forceAbs, yTrue, traj.yHat(:), ...
            alphaValues, tStopVec, titleStr, outPath, cfg, figOpts);

        pathPtr = pathPtr + 1;
        summary.outPaths(pathPtr) = outPath;
        summary.nWritten = pathPtr;
    end

    if mod(si, 10) == 0 || si == nSamples
        fprintf("  fig4 all-samples: %d / %d 試料完了\n", si, nSamples);
    end
end

summary.outPaths = summary.outPaths(1:pathPtr);

end

function keysByType = resolveExampleMethodKeysByType(cfg)
keysByType = struct();
if isfield(cfg.paper, "exampleMethodKeysByType")
    keysByType = cfg.paper.exampleMethodKeysByType;
end
defaults = struct( ...
    "percent_yield", "pct_s25_w50", ...
    "force_abs", "force_s05_w05", ...
    "force_trailing", "ftrail_f05_w05");
types = activeKrMethodTypes();
for i = 1:numel(types)
    mt = char(types(i));
    if ~isfield(keysByType, mt) || strlength(string(keysByType.(mt))) == 0
        keysByType.(mt) = defaults.(mt);
    end
end
end
