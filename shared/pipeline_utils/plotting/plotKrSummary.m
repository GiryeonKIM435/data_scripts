function plotKrSummary(cfg, pu, figRoot)
%PLOTKRSUMMARY kr 多方式のサマリー figure 出力

if ~isfile(cfg.paths.krTable)
    return;
end

s = load(cfg.paths.krTable, "krExport");
kr = s.krExport;
methods = KrMethodRegistry();
reg = PredictorRegistry();
nMethods = numel(methods);

successCounts = zeros(nMethods, 1);
labels = strings(nMethods, 1);
krCols = strings(nMethods, 1);
for m = 1:nMethods
    key = string(methods(m).key);
    labels(m) = methods(m).label;
    krCol = "kr_" + key;
    succCol = "krSuccess_" + key;
    krCols(m) = krCol;
    if ismember(succCol, kr.Properties.VariableNames)
        successCounts(m) = nnz(kr.(succCol));
    elseif key == "force_band_20_40" && ismember("krSuccess", kr.Properties.VariableNames)
        successCounts(m) = nnz(kr.krSuccess);
    end
end

fig1 = pu.newOffFigure("kr success rate", [60 60 900 520]);
pu.plotBarHorizontalWithSe(successCounts, zeros(nMethods, 1), labels, "success count", ...
    sprintf("kr success by method (n=%d samples)", height(kr)), gca);
pu.saveStageFigure(fig1, figRoot, "01_success_rate_by_method", cfg.figures);

pctIdx = arrayfun(@(x) x.type == "percent_yield", methods);
forceIdx = arrayfun(@(x) x.type == "force_abs", methods);
plotMethodHistogramGrid(cfg, pu, figRoot, kr, methods(pctIdx), ...
    "02_histogram_percent_bands", "kr histograms (percent of yield)");
plotMethodHistogramGrid(cfg, pu, figRoot, kr, methods(forceIdx), ...
    "03_histogram_force_ranges", "kr histograms (absolute force ranges)");

plotKrVsYieldGrid(cfg, pu, figRoot, kr, reg.krAnalyzeKeys, methods);
plotKrCorrelationHeatmap(cfg, pu, figRoot, kr, methods);
plotFitBandOverlay(cfg, pu, figRoot, methods);
plotFitTierHistogram(cfg, pu, figRoot, kr, methods);
plotBandPointsVsR2(cfg, pu, figRoot, kr, methods);

end

function plotMethodHistogramGrid(cfg, pu, figRoot, kr, methods, stem, ttl)
if isempty(methods)
    return;
end
n = numel(methods);
nCols = min(3, n);
nRows = ceil(n / nCols);
fig = pu.newOffFigure(stem, [60 60 320 * nCols 260 * nRows]);
t = tiledlayout(fig, nRows, nCols, "TileSpacing", "compact", "Padding", "compact");
title(t, ttl);
for m = 1:n
    ax = nexttile(t);
    key = string(methods(m).key);
    krCol = "kr_" + key;
    succCol = "krSuccess_" + key;
    vals = [];
    if ismember(krCol, kr.Properties.VariableNames) && ismember(succCol, kr.Properties.VariableNames)
        ok = kr.(succCol) & isfinite(kr.(krCol));
        vals = kr.(krCol)(ok);
    elseif key == "force_band_20_40" && ismember("kr", kr.Properties.VariableNames)
        ok = kr.krSuccess & isfinite(kr.kr);
        vals = kr.kr(ok);
    end
    if isempty(vals)
        axis(ax, "off");
        title(ax, char(methods(m).label));
        continue;
    end
    histogram(ax, vals);
    xlabel(ax, "kr [N/mm]");
    title(ax, sprintf("%s (n=%d)", methods(m).label, numel(vals)), "FontSize", 9);
    grid(ax, "on");
end
pu.saveStageFigure(fig, figRoot, stem, cfg.figures);
end

function plotKrVsYieldGrid(cfg, pu, figRoot, kr, analyzeKeys, methods)
keys = analyzeKeys(:);
n = numel(keys);
if n == 0
    return;
end
nCols = min(3, n);
nRows = ceil(n / nCols);
fig = pu.newOffFigure("kr vs yield grid", [60 60 320 * nCols 280 * nRows]);
t = tiledlayout(fig, nRows, nCols, "TileSpacing", "compact", "Padding", "compact");
title(t, "kr vs yield force (analyze keys)");
for i = 1:n
    ax = nexttile(t);
    key = string(keys(i));
    krCol = "kr_" + key;
    succCol = "krSuccess_" + key;
    label = lookupKrLabel(key, methods);
    if ismember(krCol, kr.Properties.VariableNames) && ismember(succCol, kr.Properties.VariableNames)
        ok = kr.(succCol) & isfinite(kr.(krCol)) & isfinite(kr.yieldForceN);
        scatter(ax, kr.(krCol)(ok), kr.yieldForceN(ok), 24, "filled");
    end
    xlabel(ax, "kr [N/mm]");
    ylabel(ax, "yield [N]");
    title(ax, char(label), "FontSize", 9);
    grid(ax, "on");
end
pu.saveStageFigure(fig, figRoot, "04_kr_vs_yield_grid", cfg.figures);
end

function plotKrCorrelationHeatmap(cfg, pu, figRoot, kr, methods)
n = numel(methods);
mat = nan(height(kr), n);
labels = strings(n, 1);
for m = 1:n
    key = string(methods(m).key);
    labels(m) = methods(m).label;
    krCol = "kr_" + key;
    succCol = "krSuccess_" + key;
    if ismember(krCol, kr.Properties.VariableNames)
        v = kr.(krCol);
        if ismember(succCol, kr.Properties.VariableNames)
            v(~kr.(succCol)) = nan;
        end
        mat(:, m) = v;
    elseif key == "force_band_20_40" && ismember("kr", kr.Properties.VariableNames)
        v = kr.kr;
        if ismember("krSuccess", kr.Properties.VariableNames)
            v(~kr.krSuccess) = nan;
        end
        mat(:, m) = v;
    end
end
okRows = all(isfinite(mat), 2);
if nnz(okRows) < 3
    return;
end
corrMat = corrcoef(mat(okRows, :));
fig = pu.newOffFigure("kr correlation", [60 60 1000 800]);
pu.plotCorrHeatmap(corrMat, labels, ...
    sprintf("kr method correlation (n=%d complete)", nnz(okRows)), labels, gca);
pu.saveStageFigure(fig, figRoot, "05_kr_correlation_heatmap", cfg.figures);
end

function plotFitBandOverlay(cfg, pu, figRoot, methods)
if ~isfile(cfg.paths.tomatoFiltered) || ~isfile(cfg.paths.tomatoDataset) || ~isfile(cfg.paths.noiseProfile)
    return;
end
sFilt = load(cfg.paths.tomatoFiltered, "tomatoFiltered");
sRaw = load(cfg.paths.tomatoDataset, "tomatoData");
sNoise = load(cfg.paths.noiseProfile, "noiseStats");
fitCfg = struct();
fitCfg.sigmaNoiseN = sNoise.noiseStats.sigmaNoiseN;
fitCfg.krContact = KrContactConfig();
fitCfg.krFit = KrFitConfig();
fitCfg.zeroAdjustFirstPoint = getZeroAdjustEnabled(cfg);

rawMap = containers.Map("KeyType", "double", "ValueType", "any");
for i = 1:numel(sRaw.tomatoData)
    rawMap(sRaw.tomatoData(i).id) = sRaw.tomatoData(i);
end

sampleIds = [];
for i = 1:numel(sFilt.tomatoFiltered)
    id = sFilt.tomatoFiltered(i).id;
    if ~isKey(rawMap, id)
        continue;
    end
    try
        [defLoad, forceLoad, ~, yieldInfo] = extractLoadingBranchToYield( ...
            rawMap(id).yield, sFilt.tomatoFiltered(i), fitCfg);
        rr = fitKrLinearBand(defLoad, forceLoad, yieldInfo, methods(1), fitCfg);
        if rr.success
            sampleIds(end + 1) = id; %#ok<AGROW>
        end
    catch
    end
    if numel(sampleIds) >= 5
        break;
    end
end
if isempty(sampleIds)
    return;
end
nShow = min(3, numel(sampleIds));
fig = pu.newOffFigure("fit band overlay", [60 60 420 * nShow 360]);
t = tiledlayout(fig, 1, nShow, "TileSpacing", "compact", "Padding", "compact");
title(t, "Loading curve with fit bands (sample IDs)");
colors = lines(numel(methods));
for si = 1:nShow
    ax = nexttile(t);
    id = sampleIds(si);
    filtItem = sFilt.tomatoFiltered(find([sFilt.tomatoFiltered.id] == id, 1));
    y = rawMap(id).yield;
    [defLoad, forceLoad, ~, yieldInfo] = extractLoadingBranchToYield(y, filtItem, fitCfg);
    plot(ax, defLoad, forceLoad, "k.", "MarkerSize", 4);
    hold(ax, "on");
    idxC = yieldInfo.idxContact;
    if idxC >= 1 && idxC <= numel(defLoad)
        plot(ax, defLoad(idxC), forceLoad(idxC), "rv", "MarkerSize", 8, "LineWidth", 1.2);
    end
    for m = 1:numel(methods)
        rr = fitKrBand(defLoad, forceLoad, yieldInfo, methods(m), fitCfg);
        if ~rr.success
            continue;
        end
        idxC = yieldInfo.idxContact;
        defC = defLoad(idxC:end);
        forceC = forceLoad(idxC:end);
        [bandMask, bandMeta] = resolveKrBandMask(defC, forceC, yieldInfo, methods(m), fitCfg);
        if isfield(bandMeta, "skipped") && bandMeta.skipped
            continue;
        end
        if ~any(bandMask)
            continue;
        end
        plot(ax, defC(bandMask), forceC(bandMask), ".", "Color", colors(m, :), "MarkerSize", 8);
    end
    title(ax, sprintf("ID %d", id), "FontSize", 9);
    xlabel(ax, "def [mm]"); ylabel(ax, "force [N]");
    grid(ax, "on");
end
pu.saveStageFigure(fig, figRoot, "06_fit_band_overlay_samples", cfg.figures);
end

function label = lookupKrLabel(key, methods)
label = key;
for m = 1:numel(methods)
    if string(methods(m).key) == key
        label = methods(m).label;
        return;
    end
end
end

function plotFitTierHistogram(cfg, pu, figRoot, kr, methods)
nMethods = numel(methods);
tierMat = zeros(nMethods, 3);
labels = strings(nMethods, 1);
hasTier = false;
for m = 1:nMethods
    key = string(methods(m).key);
    tierCol = "krFitTier_" + key;
    labels(m) = methods(m).label;
    if ~ismember(tierCol, kr.Properties.VariableNames)
        continue;
    end
    hasTier = true;
    tiers = kr.(tierCol);
    tierMat(m, 1) = nnz(tiers == 1);
    tierMat(m, 2) = nnz(tiers == 2);
    tierMat(m, 3) = nnz(tiers == 3);
end
if ~hasTier
    return;
end
fig = pu.newOffFigure("fit tier histogram", [60 60 1000 520]);
bar(categorical(labels), tierMat, "stacked");
legend(["tier1 strict", "tier2 relaxed", "tier3 best-effort"], "Location", "eastoutside");
ylabel("count");
title("kr fit tier by method");
xtickangle(30);
grid on;
pu.saveStageFigure(fig, figRoot, "07_fit_tier_histogram", cfg.figures);
end

function plotBandPointsVsR2(cfg, pu, figRoot, kr, methods)
failN = [];
failR2 = [];
failMethod = strings(0, 1);
for m = 1:numel(methods)
    key = string(methods(m).key);
    succCol = "krSuccess_" + key;
    r2Col = "krFitR2_" + key;
    nCol = "krNBand_" + key;
    if ~ismember(succCol, kr.Properties.VariableNames)
        continue;
    end
    mask = ~kr.(succCol);
    if ~any(mask)
        continue;
    end
    nVals = kr.(nCol)(mask);
    r2Vals = kr.(r2Col)(mask);
    ok = isfinite(nVals) | isfinite(r2Vals);
    failN = [failN; nVals(ok)]; %#ok<AGROW>
    failR2 = [failR2; r2Vals(ok)]; %#ok<AGROW>
    failMethod = [failMethod; repmat(methods(m).label, nnz(ok), 1)]; %#ok<AGROW>
end
if isempty(failN)
    return;
end
fig = pu.newOffFigure("band points vs r2 failures", [60 60 720 480]);
scatter(failN, failR2, 36, "filled");
xlabel("band points"); ylabel("R^2 (last tier attempt)");
title(sprintf("Failed fits: n vs R2 (n=%d failures)", numel(failN)));
grid on;
pu.saveStageFigure(fig, figRoot, "08_band_points_vs_r2", cfg.figures);
end
