function [sampleCtx, fitCfg, cacheHit] = loadQ4DeploySampleCtx(cfg, cohort)
%loadQ4DeploySampleCtx Q4 用 sampleCtx（Q3 キャッシュ再利用）

cohortTag = cfg.cache.cohortAnalysisTag;
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
    cohortTag = char(cfg.cache.cohortAnalysisTag);
end

sampleCtxFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_sample_ctx"));
sampleCache = loadDeploySampleContextCache(cfg, cohortTag, sampleCtxFp);
cacheHit = false;

if sampleCache.hit && numel(sampleCache.sampleCtx) == cohort.n
    sampleCtx = sampleCache.sampleCtx;
    cacheHit = true;
else
    buildDeploySampleContextCache(cfg, cohort, struct( ...
        "analysisTag", cohortTag, "forceRebuild", true));
    sampleCache = loadDeploySampleContextCache(cfg, cohortTag, sampleCtxFp);
    if sampleCache.hit
        sampleCtx = sampleCache.sampleCtx;
        cacheHit = true;
    else
        artifacts = loadDeployRawArtifacts(cfg);
        fitCfg = artifacts.fitCfg;
        n = cohort.n;
        ids = cohort.ids;
        timeOrder = cfg.deploy.timeOrder;
        sampleCtx = cell(n, 1);
        for i = 1:n
            sampleCtx{i} = prepareSampleDeployContext(artifacts, ids(i), timeOrder);
        end
        return;
    end
end

artifacts = loadDeployRawArtifacts(cfg);
fitCfg = artifacts.fitCfg;

end
