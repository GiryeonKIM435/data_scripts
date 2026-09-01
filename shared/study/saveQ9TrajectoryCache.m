function cachePath = saveQ9TrajectoryCache(cacheDir, lowKey, highKey, sampleIds, trajectories, fingerprint)
%saveQ9TrajectoryCache Q9 piecewise kr 軌跡キャッシュを保存

if ~isfolder(cacheDir)
    mkdir(cacheDir);
end
cachePath = q9TrajectoryCachePath(cacheDir, lowKey, highKey);

cache = struct();
cache.fingerprint = fingerprint;
cache.lowMethodKey = char(lowKey);
cache.highMethodKey = char(highKey);
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
