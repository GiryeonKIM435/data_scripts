function cachePath = buildDeploySampleContextCache(cfg, cohort, opts)
%BUILDDEPLOYSAMPLECONTEXTCACHE 試料ごとの零点調整済み時系列をキャチE��ュ

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "analysisTag")
    opts.analysisTag = "burgers_iqr2";
end
if ~isfield(opts, "forceRebuild")
    opts.forceRebuild = false;
end

fingerprint = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_sample_ctx"));
if ~opts.forceRebuild && cfg.cache.enabled
    loaded = loadDeploySampleContextCache(cfg, opts.analysisTag, fingerprint);
    if loaded.hit
        cachePath = loaded.cachePath;
        return;
    end
end

timeOrder = cfg.deploy.timeOrder;
artifacts = loadDeployRawArtifacts(cfg);
ids = cohort.ids(:);
sampleCtx = buildDeploySampleContexts(cfg, artifacts, ids, timeOrder, ...
    struct("progressPrefix", "beforeQ3 sampleCtx"));

cacheDir = resolveDeployCacheDir(cfg, opts.analysisTag);
cachePath = fullfile(cacheDir, "deploy_sample_contexts.mat");

cache = struct();
cache.fingerprint = fingerprint;
cache.analysisTag = char(opts.analysisTag);
cache.ids = ids;
cache.timeOrder = char(timeOrder);
cache.zeroAdjustFirstPoint = logical(artifacts.fitCfg.zeroAdjustFirstPoint);
cache.krContactFingerprint = krContactConfigFingerprint();
cache.branchMode = "extractLoadingBranchToYield";
cache.sampleCtx = sampleCtx;
cache.createdAt = datetime("now");

save(cachePath, "cache", "-v7");

end
