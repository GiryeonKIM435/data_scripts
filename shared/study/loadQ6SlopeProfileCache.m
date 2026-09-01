function out = loadQ6SlopeProfileCache(cfg, analysisTag, fingerprint)
%loadQ6SlopeProfileCache q6_slope_profiles.mat を読み込み

out = struct();
out.hit = false;
out.cachePath = "";
out.profiles = [];

if ~cfg.cache.enabled || ~isfield(cfg, "q6") || ~cfg.q6.reuseCache
    return;
end

cachePath = fullfile(resolveDeployCacheDir(cfg, analysisTag), "q6_slope_profiles.mat");
if ~isfile(cachePath)
    return;
end

s = load(cachePath, "cache");
if ~isfield(s, "cache")
    return;
end
cache = s.cache;

if ~fingerprintsMatch(cache.fingerprint, fingerprint)
    return;
end

out.hit = true;
out.cachePath = cachePath;
out.profiles = cache.profiles;

end

function ok = fingerprintsMatch(a, b)
ok = studyFingerprintsMatch(a, b);  % パス正規化比較（移設キャッシュ互換）


end
