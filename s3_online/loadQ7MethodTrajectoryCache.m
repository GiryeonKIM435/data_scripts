function out = loadQ7MethodTrajectoryCache(cacheDir, methodKey, sampleIds, fingerprint)
%loadQ7MethodTrajectoryCache Q7 用軌跡読込（fingerprint 不一致でも sampleIds 一致なら採用）

out = struct();
out.hit = false;
out.trajectories = cell(0, 1);
out.fingerprint = fingerprint;
out.relaxed = false;

strict = loadMethodTrajectoryCache(cacheDir, methodKey, sampleIds, fingerprint);
if strict.hit
    out.hit = true;
    out.trajectories = strict.trajectories;
    return;
end

trajDir = fullfile(cacheDir, "traj");
cachePath = fullfile(trajDir, char(methodKey) + ".mat");
if ~isfile(cachePath)
    return;
end

try
    s = load(cachePath, "cache");
catch
    return;
end
if ~isfield(s, "cache") || ~isfield(s.cache, "sampleIds") || ~isfield(s.cache, "trajectories")
    return;
end
cachedIds = s.cache.sampleIds(:);
sampleIds = sampleIds(:);
if numel(cachedIds) ~= numel(sampleIds) || any(cachedIds ~= sampleIds)
    return;
end

out.hit = true;
out.trajectories = s.cache.trajectories;
out.relaxed = true;
if isfield(s.cache, "fingerprint")
    out.fingerprint = s.cache.fingerprint;
end
end
