function online = runQ5OnlineDeploy(cfg, cohort, caseReduced, krMethodKey, krCol, q3AnalysisTag, outDir)
%runQ5OnlineDeploy ケース別オンラインチE�Eロイ�E�E3 軌跡キャチE��ュ再利用�E�E

methods = KrMethodRegistry();
mdef = lookupKrMethod(krMethodKey, methods);
[leakCat, leakNote] = krLeakageCategory(krMethodKey, mdef);
meta = struct( ...
    "methodType", char(mdef.type), ...
    "gridStart", mdef.gridStart, ...
    "gridWidth", mdef.gridWidth, ...
    "gridValid", mdef.gridValid, ...
    "label", char(mdef.label), ...
    "leakCategory", char(leakCat), ...
    "leakNote", char(leakNote));

y = cohort.y;
ids = cohort.ids;
tbl = cohort.predictorTable;
n = cohort.n;
krBatch = tbl{:, char(krCol)};

alphaValues = cfg.deploy.alphaValues(:);
if isfield(cfg, "q5") && isfield(cfg.q5, "alphaValues")
    alphaValues = cfg.q5.alphaValues(:);
end

perSampleAlpha = isfield(cfg, "q5") && isfield(cfg.q5, "perSampleDesignAlpha") ...
    && logical(cfg.q5.perSampleDesignAlpha);
if perSampleAlpha
    gammaTag = "gamma_1p0";
    if isfield(cfg.q5, "designAlphaGammaTag") && strlength(string(cfg.q5.designAlphaGammaTag)) > 0
        gammaTag = char(string(cfg.q5.designAlphaGammaTag));
    end
    alphaValues = loadQ7DesignAlphaPerSample(cfg, krMethodKey, ids, gammaTag, q3AnalysisTag);
    nAlpha = 1;
    fprintf("Q5 online: fold-specific alpha_design^(-i) from Q7 (%s / %s), median=%.4f\n", ...
        gammaTag, krMethodKey, median(alphaValues, "omitnan"));
else
    nAlpha = numel(alphaValues);
end
krVariant = cfg.deploy.krVariant;
if isfield(cfg, "q5") && isfield(cfg.q5, "krVariant")
    krVariant = char(string(cfg.q5.krVariant));
end

cacheDir = resolveDeployCacheDir(cfg, q3AnalysisTag);
cohortTag = "burgers_no_iqr";
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
    cohortTag = char(cfg.cache.cohortAnalysisTag);
end

sampleCtxFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_sample_ctx"));
sampleCache = loadDeploySampleContextCache(cfg, cohortTag, sampleCtxFp);
if sampleCache.hit && numel(sampleCache.sampleCtx) == n
    sampleCtx = sampleCache.sampleCtx;
else
    buildDeploySampleContextCache(cfg, cohort, struct("analysisTag", cohortTag, "forceRebuild", true));
    sampleCache = loadDeploySampleContextCache(cfg, cohortTag, sampleCtxFp);
    if ~sampleCache.hit
        error("runQ5OnlineDeploy:NoSampleCtx", "deploy sample context could not be built.");
    end
    sampleCtx = sampleCache.sampleCtx;
end

artifacts = loadDeployRawArtifacts(cfg);
fitCfg = artifacts.fitCfg;
trajFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_traj"));
trajCached = loadMethodTrajectoryCache(cacheDir, krMethodKey, ids, trajFp);
if trajCached.hit
    trajCell = trajCached.trajectories;
else
    fprintf("Q5: 軌跡キャチE��ュなぁEↁE%s を構築中...\n", krMethodKey);
    calibUni = fitDeployCalibLoocv(krBatch, y);
    yminCohortAbs = computeCohortYieldMin(y);
    built = buildMethodKrTrajectories(cfg, sampleCtx, y, mdef, fitCfg, calibUni, ...
        yminCohortAbs, krVariant, false, sprintf("Q5 traj %s", krMethodKey));
    trajCell = built;
    if cfg.cache.enabled
        saveMethodTrajectoryCache(cacheDir, krMethodKey, ids, trajCell, trajFp);
    end
end

summaryAll = {};
perSampleAll = {};

for ci = 1:numel(caseReduced)
    cr = caseReduced(ci);
    preds = cr.selected;
    if isempty(preds)
        continue;
    end
    onlinePreds = preds;
    if ~ismember(krCol, onlinePreds)
        % Online stopping requires time-varying kr(t); add kr as dynamic predictor.
        onlinePreds = [string(krCol); string(onlinePreds(:))];
    end
    fprintf("Q5 online deploy: %s (%d predictors)\n", cr.caseId, numel(onlinePreds));

    if numel(onlinePreds) == 1 && onlinePreds(1) == krCol
        calib = fitDeployCalibLoocv(krBatch, y);
        calib.type = "univariate";
    else
        calib = fitDeployCalibMultivariateLoocv(tbl, y, onlinePreds, krCol);
    end

    foldOutcomes = cell(nAlpha, 1);
    for ai = 1:nAlpha
        foldOutcomes{ai} = repmat(emptyOutcome(), n, 1);
    end

    perRows = cell(n * nAlpha, 19);
    rowPtr = 0;
    for i = 1:n
        if ~isDeployCalibFoldValid(calib, i)
            if perSampleAlpha
                o = emptyOutcome();
                o.outcome = "fail_no_kr";
                o.yTrue = y(i);
                o.alpha = alphaValues(i);
                foldOutcomes{1}(i) = o;
                rowPtr = rowPtr + 1;
                perRows(rowPtr, :) = packQ5PerSampleRow(ids(i), cr.caseId, krMethodKey, ...
                    alphaValues(i), o, meta);
            else
                for ai = 1:nAlpha
                    o = emptyOutcome();
                    o.outcome = "fail_no_kr";
                    o.yTrue = y(i);
                    o.alpha = alphaValues(ai);
                    foldOutcomes{ai}(i) = o;
                    rowPtr = rowPtr + 1;
                    perRows(rowPtr, :) = packQ5PerSampleRow(ids(i), cr.caseId, krMethodKey, ...
                        alphaValues(ai), o, meta);
                end
            end
            continue;
        end

        if i <= numel(trajCell) && ~isempty(trajCell{i})
            krPath = trajCell{i};
        else
            error("runQ5OnlineDeploy:MissingTraj", "missing trajectory for sample %d", ids(i));
        end

        traj = applyDeployCalibToSampleTrajectory(krPath, y(i), calib, i, tbl, onlinePreds);
        if perSampleAlpha
            o = evalStopAlphas(traj, alphaValues(i), y(i));
            foldOutcomes{1}(i) = o;
            rowPtr = rowPtr + 1;
            perRows(rowPtr, :) = packQ5PerSampleRow(ids(i), cr.caseId, krMethodKey, ...
                alphaValues(i), o, meta);
        else
            for ai = 1:nAlpha
                o = evalStopAlphas(traj, alphaValues(ai), y(i));
                foldOutcomes{ai}(i) = o;
                rowPtr = rowPtr + 1;
                perRows(rowPtr, :) = packQ5PerSampleRow(ids(i), cr.caseId, krMethodKey, ...
                    alphaValues(ai), o, meta);
            end
        end
    end

    for ai = 1:nAlpha
        if perSampleAlpha
            alphaFinite = alphaValues(isfinite(alphaValues) & alphaValues > 0);
            if isempty(alphaFinite)
                alpha = nan;
            else
                alpha = median(alphaFinite, "omitnan");
            end
        else
            alpha = alphaValues(ai);
        end
        smeta = meta;
        smeta.krMethodKey = char(krMethodKey);
        smeta.alpha = alpha;
        smeta.caseId = char(cr.caseId);
        srow = summarizeStreamingDeployOutcomes(foldOutcomes{ai}, smeta);
        summaryAll{end + 1, 1} = {char(cr.caseId), srow.krMethodKey, srow.alpha, ...
            srow.methodType, srow.gridStart, srow.gridWidth, srow.gridValid, srow.label, ...
            srow.leakCategory, srow.leakNote, srow.nCohort, srow.nUsed, ...
            srow.safeSuccessRate, srow.safeStopRate, srow.safeStopRate_sem, srow.nSafeStopFail, ...
            srow.fail_cross_warmup, srow.fail_cross_after_pred, srow.fail_never_stopped, ...
            srow.fail_no_kr, srow.nEvaluated, srow.nNoPrediction, ...
            srow.finalUpdateMae, srow.finalUpdateMae_sem, srow.finalUpdateR2, ...
            srow.relativeFinalUpdateError_mean, srow.relativeFinalUpdateError_sem, ...
            srow.stopMae_success, srow.stopMae_success_sem, srow.stopR2_success, ...
            srow.relativeStopError_success_mean, srow.relativeStopError_success_sem, ...
            srow.warmupStepsMean, srow.warmupSteps_sem}; %#ok<AGROW>
    end
    if rowPtr > 0
        perSampleAll = [perSampleAll; perRows(1:rowPtr, :)]; %#ok<AGROW>
    end
end

summaryTable = cell2table(vertcat(summaryAll{:}), 'VariableNames', { ...
    'caseId', 'krMethodKey', 'alpha', 'methodType', 'gridStart', 'gridWidth', 'gridValid', ...
    'label', 'leakCategory', 'leakNote', 'nCohort', 'nUsed', ...
    'safeSuccessRate', 'safeStopRate', 'safeStopRate_sem', 'nSafeStopFail', ...
    'fail_cross_warmup', 'fail_cross_after_pred', 'fail_never_stopped', 'fail_no_kr', ...
    'nEvaluated', 'nNoPrediction', ...
    'finalUpdateMae', 'finalUpdateMae_sem', 'finalUpdateR2', ...
    'relativeFinalUpdateError_mean', 'relativeFinalUpdateError_sem', ...
    'stopMae_success', 'stopMae_success_sem', 'stopR2_success', ...
    'relativeStopError_success_mean', 'relativeStopError_success_sem', ...
    'warmupStepsMean', 'warmupSteps_sem'});
perSampleTable = cell2table(perSampleAll, 'VariableNames', { ...
    'id', 'caseId', 'krMethodKey', 'alpha', 'outcome', 'yTrue', 'F_stop', 't_stop', ...
    'y_hat_at_stop', 'nStepsToFirstKr', 'secToFirstKr', 'stopErrorN', ...
    'relativeStopError', ...
    't_finalUpdate', 'y_hat_finalUpdate', 'finalUpdateErrorN', 'relativeFinalUpdateError', ...
    'leakCategory', 'label'});

writetable(summaryTable, fullfile(outDir, "online_deploy_summary.csv"));
writetable(perSampleTable, fullfile(outDir, "online_deploy_per_sample.csv"));

online = struct();
online.summaryTable = summaryTable;
online.perSampleTable = perSampleTable;

end

function o = emptyOutcome()
o = struct("outcome", "", "yTrue", nan, "alpha", nan, "F_stop", nan, ...
    "t_stop", nan, "y_hat_at_stop", nan, "kr_at_stop", nan, ...
    "F_lastUpdate", nan, "F_used", nan, ...
    "nStepsToFirstKr", nan, "secToFirstKr", nan, "hadValidKr", false, ...
    "nStepsTotal", nan, "stopErrorN", nan, "relativeStopError", nan, ...
    "isSafeStop", false, ...
    "stoppingMargin", nan, "stopForceRatio", nan, ...
    "t_finalUpdate", nan, "F_finalUpdate", nan, "y_hat_finalUpdate", nan, ...
    "finalUpdateErrorN", nan, "relativeFinalUpdateError", nan);
end

function row = packQ5PerSampleRow(id, caseId, methodKey, alpha, o, meta)
row = {id, char(caseId), char(methodKey), alpha, char(o.outcome), o.yTrue, o.F_stop, o.t_stop, ...
    o.y_hat_at_stop, o.nStepsToFirstKr, o.secToFirstKr, o.stopErrorN, ...
    o.relativeStopError, ...
    o.t_finalUpdate, o.y_hat_finalUpdate, o.finalUpdateErrorN, o.relativeFinalUpdateError, ...
    meta.leakCategory, meta.label};
end

function m = lookupKrMethod(key, methods)
m = methods(1);
for i = 1:numel(methods)
    if string(methods(i).key) == string(key)
        m = methods(i);
        return;
    end
end
end
