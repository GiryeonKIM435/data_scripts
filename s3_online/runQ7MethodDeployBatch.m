function [summaryTable, perSampleTable, packs] = runQ7MethodDeployBatch(cfg, cohort, ...
    methodOrder, methodMeta, krBatches, sampleCtx, fitCfg, calibByKey, ...
    alphaPerMethod, trajCacheDir, trajFp, progressPrefix)
%runQ7MethodDeployBatch 方式並列ストリーミング停止評価
%
% alphaPerMethod:
%   - nMethods×1 ベクトル: 方式ごと共通 1 α
%   - 1×nAlpha または nAlpha×1 ベクトル: 全方式共通の alpha グリッド
%   - nMethods×nSamples 行列: 外側fold（試料）ごとの設計 α

y = cohort.y(:);
ids = cohort.ids(:);
nMethods = numel(methodOrder);
n = numel(y);

[modePerMethod, modePerSample, alphaGrid] = resolveAlphaMode(alphaPerMethod, nMethods, n);

useParfor = shouldUseMethodParallel(cfg, nMethods, "deploy");
parallelSamples = shouldUseSampleParallel(cfg, nMethods, "deploy");
if isfield(cfg, "q7") && isfield(cfg.q7, "useParfor") && ~cfg.q7.useParfor
    useParfor = false;
end
if isfield(cfg, "q7") && isfield(cfg.q7, "parallelSamples")
    parallelSamples = logical(cfg.q7.parallelSamples) && ~useParfor;
end

methodOptsCell = cell(nMethods, 1);
for mi = 1:nMethods
    key = char(methodOrder(mi));
    mo = struct();
    mo.trajectoryCacheDir = trajCacheDir;
    mo.trajFingerprint = trajFp;
    mo.saveTrajectoryCache = cfg.cache.enabled && cfg.q7.saveTrajectoryCache;
    mo.krVariant = cfg.deploy.krVariant;
    if isKey(calibByKey, key)
        mo.calib = calibByKey(key);
    end
    mo.parallelSamples = parallelSamples;
    mo.cfg = cfg;
    mo.perSampleAlpha = modePerSample;
    probed = loadQ7MethodTrajectoryCache(trajCacheDir, methodOrder(mi), ids, trajFp);
    if probed.hit
        mo.trajFingerprint = probed.fingerprint;
        mo.saveTrajectoryCache = false;
    end
    methodOptsCell{mi} = mo;
end

packs = cell(nMethods, 1);
tStart = tic;
fprintf("%s: %d methods 開始 (parfor=%d, perSampleAlpha=%d)\n", ...
    progressPrefix, nMethods, useParfor, modePerSample);
drawnow("limitrate");

if useParfor
    pool = gcp("nocreate");
    if isempty(pool)
        poolInfo = ensurePaperStudyParallelPool(cfg); %#ok<NASGU>
        pool = gcp("nocreate");
    end
    tasks = repmat(struct("fn", [], "args", {{}}, "label", "", "nOut", 1), nMethods, 1);
    for mi = 1:nMethods
        alphas = pickMethodAlphas(alphaPerMethod, alphaGrid, mi, modePerMethod, modePerSample);
        tasks(mi).fn = @runStreamingDeployMethod;
        tasks(mi).args = {methodOrder(mi), methodMeta{mi}, krBatches{mi}, y, ids, ...
            sampleCtx, alphas, fitCfg, methodOptsCell{mi}};
        tasks(mi).label = char(methodOrder(mi));
        tasks(mi).nOut = 1;
    end
    pollSec = 5;
    if nMethods > 50
        pollSec = 10;
    end
    packResults = runParallelTaskBatch(pool, tasks, struct( ...
        "prefix", progressPrefix, ...
        "pollSeconds", pollSec, ...
        "tStart", tStart));
    for mi = 1:nMethods
        packs{mi} = packResults{mi};
    end
else
    for mi = 1:nMethods
        alphas = pickMethodAlphas(alphaPerMethod, alphaGrid, mi, modePerMethod, modePerSample);
        packs{mi} = runStreamingDeployMethod( ...
            methodOrder(mi), methodMeta{mi}, krBatches{mi}, y, ids, ...
            sampleCtx, alphas, fitCfg, methodOptsCell{mi});
        logStudyProgress(progressPrefix, mi, nMethods, char(methodOrder(mi)), tStart);
    end
end

if modePerSample
    nAlphaExpect = 1;
elseif modePerMethod
    nAlphaExpect = 1;
else
    nAlphaExpect = numel(alphaGrid);
end

summaryRows = cell(nMethods * nAlphaExpect, 33);
perSampleRows = cell(nMethods * nAlphaExpect * n, 21);
summaryPtr = 0;
perPtr = 0;
for mi = 1:nMethods
    pack = packs{mi};
    nAi = size(pack.summaryRows, 1);
    for ai = 1:nAi
        summaryPtr = summaryPtr + 1;
        summaryRows(summaryPtr, :) = pack.summaryRows(ai, :);
    end
    nRows = size(pack.perSampleRows, 1);
    perSampleRows(perPtr + (1:nRows), :) = pack.perSampleRows;
    perPtr = perPtr + nRows;
end

summaryTable = cell2table(summaryRows(1:summaryPtr, :), 'VariableNames', { ...
    'krMethodKey', 'alpha', 'methodType', 'gridStart', 'gridWidth', 'gridValid', ...
    'label', 'leakCategory', 'leakNote', 'nCohort', 'nUsed', ...
    'safeSuccessRate', 'safeStopRate', 'safeStopRate_sem', 'nSafeStopFail', ...
    'fail_cross_warmup', 'fail_cross_after_pred', ...
    'fail_never_stopped', 'fail_no_kr', ...
    'nEvaluated', 'nNoPrediction', ...
    'finalUpdateMae', 'finalUpdateMae_sem', 'finalUpdateR2', ...
    'relativeFinalUpdateError_mean', 'relativeFinalUpdateError_sem', ...
    'stopMae_success', 'stopMae_success_sem', 'stopR2_success', ...
    'relativeStopError_success_mean', 'relativeStopError_success_sem', ...
    'warmupStepsMean', 'warmupSteps_sem'});

strCols = ["krMethodKey", "methodType", "label", "leakCategory", "leakNote"];
for si = 1:numel(strCols)
    c = strCols(si);
    summaryTable.(c) = fillmissing(string(summaryTable.(c)), "constant", "");
end

perSampleTable = cell2table(perSampleRows(1:perPtr, :), 'VariableNames', { ...
    'id', 'krMethodKey', 'alpha', 'outcome', 'yTrue', 'F_stop', 't_stop', ...
    'y_hat_at_stop', 'F_lastUpdate', 'F_used', 'nStepsToFirstKr', 'secToFirstKr', ...
    'stopErrorN', 'relativeStopError', ...
    't_finalUpdate', 'F_finalUpdate', 'y_hat_finalUpdate', ...
    'finalUpdateErrorN', 'relativeFinalUpdateError', ...
    'leakCategory', 'label'});

fprintf("%s: 完了 %.0fs\n", progressPrefix, toc(tStart));
end

function [modePerMethod, modePerSample, alphaGrid] = resolveAlphaMode(alphaPerMethod, nMethods, nSamples)
modePerMethod = false;
modePerSample = false;
alphaGrid = [];

if isvector(alphaPerMethod) && size(alphaPerMethod, 1) == nMethods ...
        && size(alphaPerMethod, 2) == 1
    modePerMethod = true;
    return;
end

if ismatrix(alphaPerMethod) && size(alphaPerMethod, 1) == nMethods ...
        && size(alphaPerMethod, 2) == nSamples
    modePerSample = true;
    return;
end

if isvector(alphaPerMethod)
    alphaGrid = alphaPerMethod(:);
    return;
end

error("runQ7MethodDeployBatch:BadAlpha", ...
    "alphaPerMethod の形が不正です（期待: nMethods×1 / nMethods×nSamples / nAlpha×1）。");
end

function alphas = pickMethodAlphas(alphaPerMethod, alphaGrid, mi, modePerMethod, modePerSample)
if modePerSample
    alphas = alphaPerMethod(mi, :).';
elseif modePerMethod
    alphas = alphaPerMethod(mi);
else
    alphas = alphaGrid;
end
end
