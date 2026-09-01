function cachePath = saveQ4CalibCache(cfg, analysisTag, calib, krBatch, fingerprint, meta)
%saveQ4CalibCache Q4 offline calib と kr バッチを保存

cacheDir = resolveDeployCacheDir(cfg, analysisTag);
cachePath = fullfile(cacheDir, "q4_calib.mat");

cache = struct();
cache.fingerprint = fingerprint;
cache.analysisTag = char(analysisTag);
cache.calib = calib;
cache.krBatch = krBatch(:);
cache.meta = meta;
cache.createdAt = datetime("now");

save(cachePath, "cache", "-v7");

end
