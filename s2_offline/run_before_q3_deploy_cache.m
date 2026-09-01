function report = run_before_q3_deploy_cache(cfg, opts)
%RUN_BEFORE_Q3_DEPLOY_CACHE Q3 用共有キャチE��ュの事前構篁E

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "analysisTag")
    opts.analysisTag = "burgers_iqr2";
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
end
if ~isfield(opts, "mode")
    opts.mode = cfg.deploy.mode;
end
if ~isfield(opts, "forceRebuild")
    opts.forceRebuild = false;
end
if ~isfield(opts, "q1Results")
    opts.q1Results = [];
end

tStart = tic;
cohortTag = cohortCacheTag(cfg);

if opts.forceRebuild
    clearDeployStudyCache(cfg, struct("analysisTag", cohortTag));
end

poolInfo = ensurePaperStudyParallelPool(cfg);

if ~isempty(opts.q1Results) && isfield(opts.q1Results, "cohort") ...
        && opts.q1Results.useOutlierFilter == opts.useOutlierFilter
    cohort = opts.q1Results.cohort;
else
    cohort = loadStudyCohort(cfg, struct("useOutlierFilter", opts.useOutlierFilter));
end

[methodKeys, pickMeta] = resolveDeployMethodKeys(cfg, opts);
fprintf("beforeQ3: mode=%s, %d methods [%s], pool=%d workers\n", ...
    pickMeta.mode, numel(methodKeys), pickMeta.source, poolInfo.nWorkers);

fprintf("beforeQ3 [1/3] sampleCtx (%s) ...\n", cohortTag);
ctxReport = struct("hit", false, "built", false);
ctxFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_sample_ctx"));
if ~opts.forceRebuild && cfg.cache.enabled
    ctxLoaded = loadDeploySampleContextCache(cfg, cohortTag, ctxFp);
    if ctxLoaded.hit
        ctxReport.hit = true;
        sampleCtx = ctxLoaded.sampleCtx;
    end
end
if ~ctxReport.hit
    fprintf("beforeQ3 sampleCtx: fingerprint 不一致また�E未構築�Eため再構篁E(%d 試斁E\n", cohort.n);
    buildDeploySampleContextCache(cfg, cohort, struct( ...
        "analysisTag", cohortTag, "forceRebuild", true));
    ctxLoaded = loadDeploySampleContextCache(cfg, cohortTag, ctxFp);
    if ctxLoaded.hit
        ctxReport.built = true;
        sampleCtx = ctxLoaded.sampleCtx;
        fprintf("beforeQ3 sampleCtx: 構築完亁En");
    else
        error("run_before_q3_deploy_cache:SampleCtxFailed", ...
            "deploy_sample_contexts の構築に失敗しました。");
    end
else
    fprintf("beforeQ3 sampleCtx: キャチE��ュヒッチEn");
end

fprintf("beforeQ3 [2/3] calib (%s) ...\n", cohortTag);
calibOut = ensureDeployCalibCache(cfg, cohort, struct( ...
    "analysisTag", cohortTag, ...
    "forceRebuild", opts.forceRebuild, ...
    "q1Results", opts.q1Results));

if calibOut.hit && ~calibOut.built
    fprintf("beforeQ3 calib: キャチE��ュヒッチEn");
elseif calibOut.built
    fprintf("beforeQ3 calib: 構築完亁E(source=%s)\n", calibOut.source);
end

artifacts = loadDeployRawArtifacts(cfg);
fitCfg = artifacts.fitCfg;
methods = KrMethodRegistry();
methodOrder = orderMethodKeys(methodKeys, methods, cfg.deploy.runForceAbsFirst);

fprintf("beforeQ3 [3/3] traj (%s, %d 方弁E ...\n", opts.analysisTag, numel(methodOrder));
calibFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_calib"));
calibLoaded = loadDeployCalibCache(cfg, cohortTag, calibFp, methodOrder, cohort.n);
calibByKey = containers.Map("KeyType", "char", "ValueType", "any");
if calibLoaded.hit
    for mi = 1:numel(methodOrder)
        key = char(methodOrder(mi));
        idx = find(string(calibLoaded.methodKeys) == string(methodOrder(mi)), 1);
        if ~isempty(idx)
            calibByKey(key) = calibLoaded.deployCalibChord{idx};
        end
    end
end
trajReport = prewarmDeployTrajectoryCache(cfg, opts, cohort, sampleCtx, fitCfg, methodOrder, calibByKey);

report = struct();
report.createdAt = datetime("now");
report.analysisTag = opts.analysisTag;
report.cohortAnalysisTag = cohortTag;
report.mode = pickMeta.mode;
report.nMethods = numel(methodOrder);
report.pool = poolInfo;
report.sampleCtxHit = ctxReport.hit;
report.sampleCtxBuilt = ctxReport.built;
report.calibHit = calibOut.hit && ~calibOut.built;
report.calibBuilt = calibOut.built;
report.calibSource = calibOut.source;
report.trajSkipped = trajReport.trajSkipped;
report.trajBuilt = trajReport.trajBuilt;
report.trajElapsedSeconds = trajReport.elapsedSeconds;
report.elapsedSeconds = toc(tStart);

fprintf("beforeQ3 完亁E %.0fs (ctx=%d built=%d, calib=%s, traj skip=%d built=%d in %.0fs)\n", ...
    report.elapsedSeconds, report.sampleCtxHit, report.sampleCtxBuilt, ...
    report.calibSource, report.trajSkipped, report.trajBuilt, report.trajElapsedSeconds);

end

function order = orderMethodKeys(methodKeys, methods, forceAbsFirst)
if nargin < 3 || isempty(forceAbsFirst) || ~forceAbsFirst
    order = methodKeys(:);
    return;
end
priority = struct("force_abs", 1, "force_trailing", 2, "percent_yield", 3);
scores = 99 * ones(numel(methodKeys), 1);
for i = 1:numel(methodKeys)
    mdef = lookupMethod(methodKeys(i), methods);
    t = char(string(mdef.type));
    if isfield(priority, t)
        scores(i) = priority.(t);
    end
end
[~, ord] = sort(scores);
order = methodKeys(ord);
end

function m = lookupMethod(key, methods)
m = methods(1);
for i = 1:numel(methods)
    if string(methods(i).key) == string(key)
        m = methods(i);
        return;
    end
end
end

function tag = cohortCacheTag(cfg)
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
    tag = char(cfg.cache.cohortAnalysisTag);
else
    tag = "burgers_iqr2";
end

end
