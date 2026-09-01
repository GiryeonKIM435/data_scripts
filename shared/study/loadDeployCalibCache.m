function out = loadDeployCalibCache(cfg, analysisTag, fingerprint, methodKeys, nSamples)
%loadDeployCalibCache deploy_calib_chord.mat を読み込み
%
% nSamples（任意）: 指定時は calib.a/b の長さが一致しないキャッシュを拒否

out = struct();
out.hit = false;
out.deployCalibChord = cell(0, 1);
out.methodKeys = string.empty(0, 1);

if nargin < 5
    nSamples = [];
end

if ~cfg.cache.enabled || ~cfg.deploy.reuseCache
    return;
end

cachePath = fullfile(resolveDeployCacheDir(cfg, analysisTag), "deploy_calib_chord.mat");
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

cachedKeys = string(cache.methodKeys(:));
reqKeys = string(methodKeys(:));
if ~all(ismember(reqKeys, cachedKeys))
    return;
end

if ~isempty(nSamples) && ~isDeployCalibChordCompatible(cache.deployCalibChord, nSamples)
    return;
end

out.hit = true;
out.deployCalibChord = cache.deployCalibChord;
out.methodKeys = cachedKeys;

end

function ok = fingerprintsMatch(a, b)
ok = studyFingerprintsMatch(a, b);  % パス正規化比較（移設キャッシュ互換）


end
