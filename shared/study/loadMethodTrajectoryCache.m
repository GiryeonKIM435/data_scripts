function out = loadMethodTrajectoryCache(cacheDir, methodKey, sampleIds, fingerprint)
%loadMethodTrajectoryCache 方式別 kr 軌跡キャッシュを読み込み

out = struct();
out.hit = false;
out.trajectories = cell(0, 1);

trajDir = fullfile(cacheDir, "traj");
cachePath = fullfile(trajDir, char(methodKey) + ".mat");
if ~isfile(cachePath)
    return;
end

try
    s = load(cachePath, "cache");
catch me
    warning("loadMethodTrajectoryCache:CorruptFile", ...
        "軌跡キャッシュ %s が読めません（破損の可能性）。再構築します: %s", ...
        cachePath, me.message);
    discardCorruptCacheFile(cachePath);
    return;
end
if ~isfield(s, "cache")
    warning("loadMethodTrajectoryCache:InvalidFile", ...
        "軌跡キャッシュ %s に cache 変数がありません。再構築します。", cachePath);
    discardCorruptCacheFile(cachePath);
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

function discardCorruptCacheFile(cachePath)
try
    if isfile(cachePath)
        delete(cachePath);
    end
catch
end
end
