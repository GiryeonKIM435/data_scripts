function cachePath = saveDeployCalibCache(cfg, analysisTag, methodKeys, deployCalibChord, fingerprint)
%saveDeployCalibCache Q1 chord LOO キャリブ (a,b) を保存

cacheDir = resolveDeployCacheDir(cfg, analysisTag);
cachePath = fullfile(cacheDir, "deploy_calib_chord.mat");

cache = struct();
cache.fingerprint = fingerprint;
cache.analysisTag = char(analysisTag);
cache.methodKeys = methodKeys(:);
cache.deployCalibChord = deployCalibChord;
cache.createdAt = datetime("now");

save(cachePath, "cache", "-v7");

end
