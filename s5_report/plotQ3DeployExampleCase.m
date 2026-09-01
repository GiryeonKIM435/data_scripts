function outPaths = plotQ3DeployExampleCase(cfg, cohort, outDir)
%plotQ3DeployExampleCase 方式種別ごとの online デプロイ実施例（力–時間、複数 α）

if nargin < 3 || isempty(outDir)
    outDir = cfg.out.paperFigures;
end
if ~isfolder(outDir)
    mkdir(outDir);
end

sampleId = cfg.paper.exampleSampleId;
alphaValues = cfg.deploy.alphaValues(:);
methodTypes = activeKrMethodTypes();
prefixByType = struct( ...
    "percent_yield", "yield_pct", ...
    "force_abs", "force_abs", ...
    "force_trailing", "force_trail");
keysByType = resolveExampleMethodKeysByType(cfg);

idx = find(cohort.ids == sampleId, 1);
if isempty(idx)
    error("plotQ3DeployExampleCase:MissingSample", ...
        "exampleSampleId=%d がコホートにありません。", sampleId);
end

methods = KrMethodRegistry();
[sampleCtx, fitCfg, ~] = loadQ4DeploySampleCtx(cfg, cohort);
ctx = sampleCtx{idx};
yTrue = cohort.y(idx);
yminCohortAbs = computeCohortYieldMin(cohort.y);

outPaths = strings(numel(methodTypes), 1);
for ti = 1:numel(methodTypes)
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
        sampleOpts.calibA = calib.a(idx);
        sampleOpts.calibB = calib.b(idx);
        sampleOpts.yminCohortAbs = yminCohortAbs;
    end

    krPath = streamDeployKrPath(ctx, yTrue, mdef, fitCfg, sampleOpts);
    traj = applyDeployCalibToTrajectory(krPath, yTrue, calib.a(idx), calib.b(idx));

    tStopVec = nan(numel(alphaValues), 1);
    for ai = 1:numel(alphaValues)
        outcome = evalStopAlphas(traj, alphaValues(ai), yTrue);
        tStopVec(ai) = outcome.t_stop;
    end

    forceOffsetN = 0;
    if isfield(ctx, "forceOffsetN") && isfinite(ctx.forceOffsetN)
        forceOffsetN = ctx.forceOffsetN;
    end
    if isfield(traj, "forceAbs")
        forceAbs = traj.forceAbs(:);
    else
        forceAbs = traj.force(:) + forceOffsetN;
    end

    outPath = fullfile(outDir, sprintf("fig4_q3_deploy_example_%s.png", prefix));
    titleStr = sprintf("Q3 deploy example (id=%d, %s)", sampleId, mdef.label);
    plotQ3DeployForceTimeMultiAlphaFigure(ctx.sec(:), forceAbs, yTrue, traj.yHat(:), ...
        alphaValues, tStopVec, titleStr, outPath, cfg);
    outPaths(ti) = outPath;
end

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
