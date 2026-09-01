function [filteredTomatoData, metadata] = filterTomatoByYield(tomatoData, noiseStats, cfg)
%FILTERTOMATOBYYIELD 降伏点検出・品質フィルタ（n3 コア、プロット任意）

sigmaNoiseN = noiseStats.sigmaNoiseN;
gapThr = cfg.detectYield.yieldGapRatioThreshold;
minForce = cfg.detectYield.minAcceptedYieldForceN;
showPlots = isfield(cfg.detectYield, "showReviewPlots") && cfg.detectYield.showReviewPlots;
zeroAdjust = getZeroAdjustEnabled(cfg);

n = numel(tomatoData);
hasPiecewise = false(1, n);
hasSingle = false(1, n);
gapExceeded = false(1, n);
lowForce = false(1, n);

for i = 1:n
    y = tomatoData(i).yield;
    [defAdj, forceAdj, ~] = zeroAdjustDefForceFirstPoint( ...
        y.deformation, y.force, zeroAdjust);
    [hp, pwDef, pwForce, hs, seDef, seForce] = detectYieldPoints( ...
        defAdj, forceAdj, sigmaNoiseN);
    hasPiecewise(i) = hp;
    hasSingle(i) = hs;
    tomatoData(i).yieldDropThreshold = struct("hasYield", hs, "deformation", seDef, "force", seForce);
    if hp && hs
        higher = max(abs([seForce, pwForce]));
        if higher > 0
            gap = abs(seForce - pwForce) / higher;
            gapExceeded(i) = gap >= gapThr;
        end
    end
    if hs && seForce <= minForce
        lowForce(i) = true;
    end
end

keepMask = hasSingle & hasPiecewise & ~gapExceeded & ~lowForce;

forceKeepIds = [];
if isfield(cfg, "detectYield") && isfield(cfg.detectYield, "forceKeepIds") ...
        && ~isempty(cfg.detectYield.forceKeepIds)
    forceKeepIds = double(cfg.detectYield.forceKeepIds(:));
end
if ~isempty(forceKeepIds)
    idsAll = arrayfun(@(x) double(x.id), tomatoData);
    forceKeep = ismember(idsAll(:), forceKeepIds) & hasSingle(:);
    nForced = nnz(forceKeep & ~keepMask(:));
    keepMask = keepMask(:) | forceKeep;
    fprintf("forceKeepIds: 追加採用 %d 果（指定 %s）\n", ...
        nForced, mat2str(forceKeepIds(:).'));
end

filteredTomatoData = tomatoData(keepMask);
keptIds = [filteredTomatoData.id];
excludedIds = [tomatoData(~keepMask).id];

fprintf("降伏フィルタ: kept=%d, excluded=%d\n", numel(keptIds), numel(excludedIds));

if showPlots
    plotYieldReview(tomatoData, hasPiecewise, hasSingle, gapExceeded, lowForce, cfg);
end

metadata = struct();
metadata.filteredAt = datetime("now");
metadata.sigmaNoiseN = sigmaNoiseN;
metadata.yieldGapRatioThreshold = gapThr;
metadata.minAcceptedYieldForceN = minForce;
metadata.keptIds = keptIds(:).';
metadata.excludedIds = excludedIds(:).';
metadata.forceKeepIds = forceKeepIds(:).';
metadata.filterMethod = "both detection methods + gap + min force";
if ~isempty(forceKeepIds)
    metadata.filterMethod = [char(metadata.filterMethod), " + forceKeepIds"];
end
metadata.zeroAdjustMethod = "first_valid_point";
metadata.zeroAdjustFingerprint = yieldZeroAdjustFingerprint(cfg);
if ~zeroAdjust
    metadata.zeroAdjustMethod = "none";
end

end

function plotYieldReview(tomatoData, hasPiecewise, hasSingle, gapExceeded, lowForce, cfg)
n = numel(tomatoData);
nCols = ceil(sqrt(n));
nRows = ceil(n / nCols);
zeroAdjust = getZeroAdjustEnabled(cfg);
fig = figure("Name", "Yield review", "Color", "w");
tl = tiledlayout(fig, nRows, nCols, "TileSpacing", "compact");
for i = 1:n
    nexttile(tl, i);
    y = tomatoData(i).yield;
    [defAdj, forceAdj, ~] = zeroAdjustDefForceFirstPoint( ...
        y.deformation, y.force, zeroAdjust);
    plot(defAdj, forceAdj, "r.", "MarkerSize", 3);
    grid on;
    title(sprintf("%03d", tomatoData(i).id));
    if ~(hasSingle(i) && hasPiecewise(i)) || gapExceeded(i) || lowForce(i)
        title(sprintf("%03d (excl)", tomatoData(i).id), "Color", [0.85 0.1 0.1]);
    end
end
end
