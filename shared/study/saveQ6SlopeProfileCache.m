function cachePath = saveQ6SlopeProfileCache(cfg, analysisTag, fingerprint, profiles)
%saveQ6SlopeProfileCache Q6 傾きプロファイルを共有キャッシュに保存

cacheDir = resolveDeployCacheDir(cfg, analysisTag);
cachePath = fullfile(cacheDir, "q6_slope_profiles.mat");

cache = struct();
cache.fingerprint = fingerprint;
cache.analysisTag = char(analysisTag);
cache.profiles = profiles;
cache.createdAt = datetime("now");

save(cachePath, "cache", "-v7");

end
