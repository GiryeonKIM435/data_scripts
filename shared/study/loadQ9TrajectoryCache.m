function out = loadQ9TrajectoryCache(cacheDir, lowKey, highKey, sampleIds, fingerprint)
%loadQ9TrajectoryCache Q9 piecewise kr 軌跡キャッシュを読み込み

out = struct();
out.hit = false;
out.trajectories = cell(0, 1);

cachePath = q9TrajectoryCachePath(cacheDir, lowKey, highKey);
if ~isfile(cachePath)
    return;
end

try
    s = load(cachePath, "cache");
catch me
    warning("loadQ9TrajectoryCache:CorruptFile", ...
        "Q9 軌跡キャッシュ %s が読めません: %s", cachePath, me.message);
    if isfile(cachePath)
        delete(cachePath);
    end
    return;
end
if ~isfield(s, "cache")
    return;
end
cache = s.cache;

if ~fingerprintsMatch(cache.fingerprint, fingerprint)
    return;
end
if numel(cache.sampleIds) ~= numel(sampleIds) || any(cache.sampleIds(:) ~= sampleIds(:))
    return;
end

out.hit = true;
out.trajectories = cache.trajectories;

end

function ok = fingerprintsMatch(a, b)
ok = studyFingerprintsMatch(a, b);  % パス正規化比較（移設キャッシュ互換）


end
