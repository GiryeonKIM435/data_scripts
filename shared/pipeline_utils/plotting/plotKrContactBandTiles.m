function plotKrContactBandTiles(cfg, pu, figRoot)
%PLOTKRCONTACTBANDTILES 全試料の変位-力曲線 + 接触点 + kr 区間（9 試料/図）

if ~isfile(cfg.paths.tomatoFiltered) || ~isfile(cfg.paths.tomatoDataset) || ~isfile(cfg.paths.noiseProfile)
    return;
end

sFilt = load(cfg.paths.tomatoFiltered, "tomatoFiltered");
sRaw = load(cfg.paths.tomatoDataset, "tomatoData");
sNoise = load(cfg.paths.noiseProfile, "noiseStats");
methods = KrMethodRegistry();
nMethods = numel(methods);

fitCfg = struct();
fitCfg.sigmaNoiseN = sNoise.noiseStats.sigmaNoiseN;
fitCfg.krContact = KrContactConfig();
fitCfg.krFit = KrFitConfig();
fitCfg.zeroAdjustFirstPoint = getZeroAdjustEnabled(cfg);

rawMap = containers.Map("KeyType", "double", "ValueType", "any");
for i = 1:numel(sRaw.tomatoData)
    rawMap(sRaw.tomatoData(i).id) = sRaw.tomatoData(i);
end

sampleList = struct("id", {}, "defLoad", {}, "forceLoad", {}, "yieldInfo", {});
for i = 1:numel(sFilt.tomatoFiltered)
    filtItem = sFilt.tomatoFiltered(i);
    id = filtItem.id;
    if ~isKey(rawMap, id)
        continue;
    end
    try
        [defLoad, forceLoad, ~, yieldInfo] = extractLoadingBranchToYield( ...
            rawMap(id).yield, filtItem, fitCfg);
        sampleList(end + 1) = struct( ... %#ok<AGROW>
            "id", id, ...
            "defLoad", defLoad, ...
            "forceLoad", forceLoad, ...
            "yieldInfo", yieldInfo);
    catch
    end
end

nSamples = numel(sampleList);
if nSamples == 0
    return;
end

samplesPerPage = 9;
nCols = 3;
nRows = 3;
nPages = ceil(nSamples / samplesPerPage);
colors = lines(nMethods);
xPadFrac = 0.02;

for page = 1:nPages
    iStart = (page - 1) * samplesPerPage + 1;
    iEnd = min(page * samplesPerPage, nSamples);
    nShow = iEnd - iStart + 1;

    fig = pu.newOffFigure("contact kr bands", [40 40 320 * nCols 280 * nRows]);
    t = tiledlayout(fig, nRows, nCols, "TileSpacing", "compact", "Padding", "compact");
    title(t, sprintf("Contact onset + kr bands (page %d/%d)", page, nPages));

    legendHandles = gobjects(nMethods, 1);
    legendLabels = strings(nMethods, 1);

    for si = 1:nShow
        ax = nexttile(t);
        item = sampleList(iStart + si - 1);
        defLoad = item.defLoad;
        forceLoad = item.forceLoad;
        yieldInfo = item.yieldInfo;

        xLim = [min(defLoad), max(defLoad)];
        xSpan = max(xLim(2) - xLim(1), eps);
        xLim = xLim + xPadFrac * xSpan * [-1, 1];

        hold(ax, "on");
        for m = 1:nMethods
            mtype = string(methods(m).type);
            if mtype == "percent_yield"
                [fLow, fHigh, fLowEff] = resolveKrBandLimits(yieldInfo, methods(m), fitCfg);
            elseif mtype == "force_abs"
                [fLow, fHigh, fLowEff] = resolveKrBandLimits(yieldInfo, methods(m), fitCfg);
            elseif mtype == "force_trailing"
                anchorForce = forceLoad(end);
                [fLow, fHigh, ~] = resolveKrTrailingBandLimits(methods(m), nan, anchorForce);
                fLowEff = fLow;
                if isfinite(fLow) && isfinite(yieldInfo.contactForceN)
                    fLowEff = max(fLow, yieldInfo.contactForceN);
                end
            else
                continue;
            end
            if ~all(isfinite([fLowEff, fHigh]))
                continue;
            end
            yLo = min(fLowEff, fHigh);
            yHi = max(fLowEff, fHigh);
            patch(ax, [xLim(1), xLim(2), xLim(2), xLim(1)], ...
                [yLo, yLo, yHi, yHi], colors(m, :), ...
                "FaceAlpha", 0.08, "EdgeColor", "none", ...
                "HandleVisibility", "off");
        end

        plot(ax, defLoad, forceLoad, "k.", "MarkerSize", 3, "HandleVisibility", "off");

        idxC = yieldInfo.idxContact;
        if idxC >= 1 && idxC <= numel(defLoad)
            plot(ax, defLoad(idxC), forceLoad(idxC), "rv", ...
                "MarkerSize", 8, "LineWidth", 1.2, "HandleVisibility", "off");
        end

        defC = defLoad(idxC:end);
        forceC = forceLoad(idxC:end);
        for m = 1:nMethods
            [bandMask, bandMeta] = resolveKrBandMask(defC, forceC, yieldInfo, methods(m), fitCfg);
            if isfield(bandMeta, "skipped") && bandMeta.skipped
                continue;
            end
            if ~any(bandMask)
                continue;
            end
            h = plot(ax, defC(bandMask), forceC(bandMask), ".", ...
                "Color", colors(m, :), "MarkerSize", 7);
            if si == 1
                legendHandles(m) = h;
                legendLabels(m) = methods(m).label;
            end
        end

        title(ax, sprintf("ID %d", item.id), "FontSize", 8);
        xlabel(ax, "def [mm]", "FontSize", 7);
        ylabel(ax, "force [N]", "FontSize", 7);
        xlim(ax, xLim);
        grid(ax, "on");
        hold(ax, "off");
    end

    for si = (nShow + 1):samplesPerPage
        ax = nexttile(t);
        axis(ax, "off");
    end

    validLegend = isgraphics(legendHandles);
    if any(validLegend)
        lg = legend(legendHandles(validLegend), legendLabels(validLegend), ...
            "Location", "eastoutside", "FontSize", 7);
        lg.NumColumns = 1;
    end

    stem = sprintf("09_contact_kr_bands_p%02d", page);
    pu.saveStageFigure(fig, figRoot, stem, cfg.figures);
end

end
