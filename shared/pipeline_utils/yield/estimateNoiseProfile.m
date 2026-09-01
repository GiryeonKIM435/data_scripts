function noiseStats = estimateNoiseProfile(cfg, tomatoData)
%ESTIMATENOISEPROFILE 0-10秒区間から共通ノイズ sigma を推定

targetIds = cfg.detectYield.noiseTargetIds;
windowSec = [0, 10];

perTomato = struct("id", {}, "nPoints", {}, "nDiff", {}, "meanForceN", {}, "sigmaNoiseN", {});
sumWeightedVar = 0;
sumDf = 0;

for i = 1:numel(targetIds)
    id = targetIds(i);
    idx = find([tomatoData.id] == id, 1, "first");
    if isempty(idx)
        error("指定IDが見つかりません: %d", id);
    end
    y = tomatoData(idx).yield;
    sec = y.sec(:);
    force = y.force(:);
    valid = isfinite(sec) & isfinite(force);
    sec = sec(valid);
    force = force(valid);
    inWindow = (sec >= windowSec(1)) & (sec <= windowSec(2));
    forceW = force(inWindow);
    nPoints = numel(forceW);
    if nPoints < 3
        error("ID %d は 0〜10秒区間の有効点が不足 (n=%d)", id, nPoints);
    end
    dForce = diff(forceW);
    nDiff = numel(dForce);
    sigmaI = std(dForce, "omitnan") / sqrt(2);
    perTomato(end + 1) = struct("id", id, "nPoints", nPoints, "nDiff", nDiff, ... %#ok<AGROW>
        "meanForceN", mean(forceW, "omitnan"), "sigmaNoiseN", sigmaI);
    df = nDiff - 1;
    sumWeightedVar = sumWeightedVar + df * sigmaI^2;
    sumDf = sumDf + df;
end

sigmaNoisePooled = sqrt(sumWeightedVar / sumDf);
noiseStats = struct();
noiseStats.createdAt = datetime("now");
noiseStats.targetIds = targetIds;
noiseStats.windowSec = windowSec;
noiseStats.method = "sigma_i = std(diff(force))/sqrt(2), pooled by dof";
noiseStats.perTomato = perTomato;
noiseStats.sigmaNoiseN = sigmaNoisePooled;
fprintf("sigmaNoise (pooled): %.6f N\n", sigmaNoisePooled);
end
