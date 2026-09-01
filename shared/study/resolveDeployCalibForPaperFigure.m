function calib = resolveDeployCalibForPaperFigure(cfg, cohort, methodKey)
%resolveDeployCalibForPaperFigure 論文 fig4 用 deploy LOO 校正 (a,b)

methodKey = string(methodKey);
analysisTag = resolvePaperQ3AnalysisTag(cfg);
if isempty(analysisTag)
    analysisTag = cohortCacheTag(cfg);
end
calibFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_calib"));
loaded = loadDeployCalibCache(cfg, analysisTag, calibFp, methodKey, cohort.n);
if loaded.hit
    idx = find(string(loaded.methodKeys) == methodKey, 1);
    calib = loaded.deployCalibChord{idx};
    return;
end
calib = computeDeployCalibForMethod(cfg, cohort, methodKey);

end

function tag = cohortCacheTag(cfg)
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag") ...
        && strlength(string(cfg.cache.cohortAnalysisTag)) > 0
    tag = char(string(cfg.cache.cohortAnalysisTag));
else
    tag = "burgers_iqr2";
end
end
