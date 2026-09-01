function out = loadQ4CalibCache(cfg, analysisTag, fingerprint, nSamples)
%loadQ4CalibCache q4_calib.mat を読み込み

out = struct();
out.hit = false;
out.calib = [];
out.krBatch = [];
out.meta = struct();
out.cachePath = "";

if nargin < 4
    nSamples = [];
end
if ~cfg.cache.enabled || ~cfg.q4.reuseCache
    return;
end

cachePath = fullfile(resolveDeployCacheDir(cfg, analysisTag), "q4_calib.mat");
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

if ~isempty(nSamples) && isfield(cache, "calib") && isstruct(cache.calib) ...
        && isfield(cache.calib, "a") && numel(cache.calib.a(:)) ~= nSamples
    return;
end

out.hit = true;
out.calib = cache.calib;
out.krBatch = cache.krBatch;
if isfield(cache, "meta")
    out.meta = cache.meta;
end
out.cachePath = cachePath;

end

function ok = fingerprintsMatch(a, b)
ok = studyFingerprintsMatch(a, b);  % パス正規化比較（移設キャッシュ互換）

end
