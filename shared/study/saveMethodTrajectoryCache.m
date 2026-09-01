function cachePath = saveMethodTrajectoryCache(cacheDir, methodKey, sampleIds, trajectories, fingerprint)
%saveMethodTrajectoryCache 方式別 kr 軌跡キャッシュを保存

trajDir = fullfile(cacheDir, "traj");
if ~isfolder(trajDir)
    mkdir(trajDir);
end
cachePath = fullfile(trajDir, char(methodKey) + ".mat");

cache = struct();
cache.fingerprint = fingerprint;
cache.methodKey = char(methodKey);
cache.sampleIds = sampleIds(:);
cache.trajectories = trajectories;
cache.createdAt = datetime("now");

tmpPath = cachePath + ".tmp.mat";
if isfile(tmpPath)
    delete(tmpPath);
end
save(tmpPath, "cache", "-v7");
if isfile(cachePath)
    delete(cachePath);
end
movefile(tmpPath, cachePath);

end
