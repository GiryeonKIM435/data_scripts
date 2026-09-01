function out = loadDeploySampleContextCache(cfg, analysisTag, fingerprint)
%loadDeploySampleContextCache deploy_sample_contexts.mat を読み込み

out = struct();
out.hit = false;
out.sampleCtx = cell(0, 1);
out.ids = zeros(0, 1);
out.cachePath = "";

if ~cfg.cache.enabled || ~cfg.deploy.reuseCache
    return;
end

cachePath = fullfile(resolveDeployCacheDir(cfg, analysisTag), "deploy_sample_contexts.mat");
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

if isfield(cache, "ids") && numel(cache.sampleCtx) ~= numel(cache.ids(:))
    return;
end

out.hit = true;
out.sampleCtx = cache.sampleCtx;
out.ids = cache.ids(:);
out.cachePath = cachePath;

end

function ok = fingerprintsMatch(a, b)
ok = studyFingerprintsMatch(a, b);  % パス正規化比較（移設キャッシュ互換）


end
