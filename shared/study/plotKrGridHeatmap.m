function plotKrGridHeatmap(valueMat, semMat, starts, widths, opts)
%plotKrGridHeatmap  kr grid ヒートマップ（mean ± SEM 表示、MIN / 非有意枠対応）

arguments
    valueMat
    semMat = []
    starts = []
    widths = []
    opts.title (1, :) char = ""
    opts.outPath (1, :) char = ""
    opts.cfg struct = struct()
    opts.clim double = []
    opts.colorbarLabel (1, :) char = ""
    opts.highlightMode (1, :) char = "none"
    opts.scaleMode (1, :) char = "abs"
    opts.showSem (1, 1) logical = true
    opts.figureSize (1, 2) double = [920, 560]
    opts.compactText (1, 1) logical = false
    opts.xLabel (1, :) char = "Start"
    opts.yLabel (1, :) char = "Band width"
    opts.eligibilityMask = []
    opts.annotationLines = []
    opts.referenceCells = {}
    opts.referenceLabel (1, :) char = "Q1"
    opts.nondiffMask = []
    opts.valueDecimals (1, 1) double = nan
end

if isempty(valueMat)
    return;
end

displayMat = valueMat;
displaySem = semMat;
if strcmpi(opts.scaleMode, "pct")
    displayMat = 100 * valueMat;
    if ~isempty(semMat)
        displaySem = 100 * semMat;
    end
end

ny = size(displayMat, 1);
nx = size(displayMat, 2);
eligibleMask = true(ny, nx);
if ~isempty(opts.eligibilityMask)
    eligibleMask = logical(opts.eligibilityMask);
    if ~isequal(size(eligibleMask), [ny, nx])
        error("plotKrGridHeatmap:MaskSize", ...
            "eligibilityMask size [%d,%d] must match valueMat [%d,%d].", ...
            size(eligibleMask, 1), size(eligibleMask, 2), ny, nx);
    end
end

plotMat = displayMat;
plotMat(~eligibleMask | ~isfinite(plotMat)) = nan;

figW = opts.figureSize(1);
figH = opts.figureSize(2);
fig = figure("Color", "w", "Position", [80 80 figW figH], "Visible", "off");
ax = axes(fig);
imagesc(ax, 1:nx, 1:ny, plotMat, "AlphaData", ~isnan(plotMat));
ax.Color = [0.8 0.8 0.8];
set(ax, "YDir", "normal");
colormap(ax, parula);
if numel(opts.clim) == 2 && all(isfinite(opts.clim))
    caxis(ax, opts.clim);
end
cb = colorbar(ax);
if strlength(string(opts.colorbarLabel)) > 0
    cb.Label.String = char(opts.colorbarLabel);
end
xlabel(ax, char(opts.xLabel));
ylabel(ax, char(opts.yLabel));
title(ax, char(opts.title));
xticks(ax, 1:nx);
yticks(ax, 1:ny);
xticklabels(ax, string(starts));
yticklabels(ax, string(widths));
xlim(ax, [0.5, nx + 0.5]);
ylim(ax, [0.5, ny + 0.5]);

for xEdge = 0.5:1:(nx + 0.5)
    line(ax, [xEdge xEdge], [0.5 ny + 0.5], "Color", [0.25 0.25 0.25], "LineWidth", 0.8);
end
for yEdge = 0.5:1:(ny + 0.5)
    line(ax, [0.5 nx + 0.5], [yEdge yEdge], "Color", [0.25 0.25 0.25], "LineWidth", 0.8);
end

paperCfg = resolvePaperTypography(opts.cfg);
cellFontSize = paperCfg.fontSizeLegend;
if opts.compactText
    cellFontSize = max(6, paperCfg.fontSizeLegend - 1);
end
ax.UserData = struct( ...
    "heatmapCellFontSize", cellFontSize, ...
    "heatmapFontName", paperCfg.fontName);

hasSem = opts.showSem && ~isempty(displaySem);
hasAnnotations = ~isempty(opts.annotationLines);
if hasAnnotations && (~iscell(opts.annotationLines) ...
        || ~isequal(size(opts.annotationLines), [ny, nx]))
    error("plotKrGridHeatmap:AnnotationSize", ...
        "annotationLines must be a %d×%d cell array.", ny, nx);
end
for yi = 1:ny
    for xi = 1:nx
        v = displayMat(yi, xi);
        if ~isfinite(v)
            continue;
        end
        txt = formatHeatmapCellText(v, displaySem, yi, xi, hasSem, ...
            opts.scaleMode, opts.compactText, opts.valueDecimals);
        if hasAnnotations
            extra = opts.annotationLines{yi, xi};
            if strlength(string(extra)) > 0
                txt = char(txt + newline + string(extra));
            end
        end
        if eligibleMask(yi, xi)
            txtColor = "k";
        else
            txtColor = [0.35 0.35 0.35];
        end
        textInterp = "none";
        if hasAnnotations
            textInterp = "tex";
        end
        text(ax, xi, yi, txt, ...
            "HorizontalAlignment", "center", "VerticalAlignment", "middle", ...
            "FontSize", cellFontSize, "FontName", paperCfg.fontName, ...
            "Color", txtColor, "Interpreter", textInterp);
    end
end

highlightMode = lower(string(opts.highlightMode));
if highlightMode == "min"
    applyMinHighlights(ax, displayMat, displaySem, "min", eligibleMask);
elseif highlightMode == "minnondiff9599" || highlightMode == "minnondiff"
    applyMinHighlights(ax, displayMat, displaySem, "minnondiff9599", eligibleMask);
elseif highlightMode == "minnondifffdr"
    applyMinFdrHighlights(ax, displayMat, eligibleMask, opts.nondiffMask);
elseif highlightMode == "max"
    applyMaxHighlights(ax, displayMat, displaySem, "max", eligibleMask);
elseif highlightMode == "maxnondiff9599" || highlightMode == "maxnondiff"
    applyMaxHighlights(ax, displayMat, displaySem, "maxnondiff9599", eligibleMask);
end

if ~isempty(opts.referenceCells)
    applyReferenceHighlights(ax, opts.referenceCells, char(opts.referenceLabel));
end

dpi = 300;
if isfield(opts.cfg, "analysis") && isfield(opts.cfg.analysis, "figureDpi")
    dpi = opts.cfg.analysis.figureDpi;
end
styleCfg = resolveHeatmapStyleCfg(opts.cfg, cellFontSize);
exportPaperFigure(fig, opts.outPath, "Resolution", dpi, "Cfg", styleCfg);

end

function txt = formatHeatmapCellText(v, displaySem, yi, xi, hasSem, scaleMode, compactText, valueDecimals)
semVal = nan;
if hasSem && ~isempty(displaySem)
    semVal = displaySem(yi, xi);
end
if isfinite(valueDecimals)
    decimals = max(0, round(valueDecimals));
    if hasSem && isfinite(semVal)
        txt = sprintf("%.*f ±%.*f", decimals, v, decimals, semVal);
    else
        txt = sprintf("%.*f", decimals, v);
    end
    if strcmpi(scaleMode, "pct")
        txt = [txt, "%"];
    end
    return;
end
if hasSem && isfinite(semVal)
    if strcmpi(scaleMode, "pct")
        if compactText
            txt = sprintf("%.0f ±%.0f%%", v, semVal);
        else
            txt = sprintf("%.1f ±%.1f%%", v, semVal);
        end
    elseif compactText
        txt = sprintf("%.1f ±%.1f", v, semVal);
    else
        txt = sprintf("%.2f ±%.2f", v, semVal);
    end
elseif strcmpi(scaleMode, "pct")
    if compactText
        txt = sprintf("%.0f%%", v);
    else
        txt = sprintf("%.1f%%", v);
    end
elseif compactText
    txt = sprintf("%.1f", v);
else
    txt = sprintf("%.2f", v);
end
end

function applyMinHighlights(ax, displayMat, displaySem, mode, eligibleMask)
if nargin < 5 || isempty(eligibleMask)
    eligibleMask = true(size(displayMat));
end
finiteMask = isfinite(displayMat) & eligibleMask;
finiteVals = displayMat(finiteMask);
if isempty(finiteVals)
    return;
end

vMin = min(finiteVals);
minColor = [0.85 0.1 0.1];
color95 = [0.98 0.78 0.86];
color99 = [0.82 0.28 0.52];

[minY, minX] = find(displayMat == vMin, 1, "first");
semMin = nan;
if ~isempty(displaySem) && isfinite(displaySem(minY, minX))
    semMin = displaySem(minY, minX);
end

[ny, nx] = size(displayMat);
minMask = finiteMask & (displayMat == vMin);

if mode == "minnondiff9599"
    z95 = 1.96;
    z99 = norminv(1 - 0.01 / 2);
    mask99 = false(ny, nx);
    mask95 = false(ny, nx);
    for yi = 1:ny
        for xi = 1:nx
            if ~finiteMask(yi, xi) || minMask(yi, xi)
                continue;
            end
            semVal = nan;
            if ~isempty(displaySem) && isfinite(displaySem(yi, xi))
                semVal = displaySem(yi, xi);
            end
            tier = nondiffTier(displayMat(yi, xi), semVal, vMin, semMin, z95, z99);
            if tier == "99"
                mask99(yi, xi) = true;
            elseif tier == "95"
                mask95(yi, xi) = true;
            end
        end
    end
    drawHighlightRegionEdges(ax, mask99, color95, 1.5);
    drawHighlightRegionEdges(ax, mask95, color99, 1.8);
end

drawHighlightRegionEdges(ax, minMask, minColor, 2.2);

end

function applyMinFdrHighlights(ax, displayMat, eligibleMask, nondiffMask)
if nargin < 3 || isempty(eligibleMask)
    eligibleMask = true(size(displayMat));
end
finiteMask = isfinite(displayMat) & eligibleMask;
finiteVals = displayMat(finiteMask);
if isempty(finiteVals)
    return;
end

vMin = min(finiteVals);
minColor = [0.85 0.1 0.1];
colorFdr = [0.82 0.28 0.52];
minMask = finiteMask & (displayMat == vMin);

fdrMask = false(size(displayMat));
if ~isempty(nondiffMask) && isequal(size(nondiffMask), size(displayMat))
    fdrMask = logical(nondiffMask) & finiteMask & ~minMask;
end
drawHighlightRegionEdges(ax, fdrMask, colorFdr, 1.9, "--");
drawHighlightRegionEdges(ax, minMask, minColor, 2.2);
end

function applyReferenceHighlights(ax, referenceCells, refLabel)
refColor = [0.1 0.55 0.2];
nx = round(ax.XLim(2) - 0.5);
ny = round(ax.YLim(2) - 0.5);
for ci = 1:numel(referenceCells)
    idx = referenceCells{ci};
    if isempty(idx) || numel(idx) ~= 2
        continue;
    end
    yi = idx(1);
    xi = idx(2);
    xLR = insetBoundaryCoords([xi - 0.5, xi + 0.5], nx);
    yBT = insetBoundaryCoords([yi - 0.5, yi + 0.5], ny);
    xL = xLR(1);
    xR = xLR(2);
    yB = yBT(1);
    yT = yBT(2);
    line(ax, [xL xR], [yB yB], "Color", refColor, "LineWidth", 1.8, "LineStyle", "--");
    line(ax, [xL xR], [yT yT], "Color", refColor, "LineWidth", 1.8, "LineStyle", "--");
    line(ax, [xL xL], [yB yT], "Color", refColor, "LineWidth", 1.8, "LineStyle", "--");
    line(ax, [xR xR], [yB yT], "Color", refColor, "LineWidth", 1.8, "LineStyle", "--");
    if strlength(string(refLabel)) > 0
        text(ax, xi, yi + 0.38, refLabel, "Color", refColor, ...
            "HorizontalAlignment", "center", "VerticalAlignment", "top", ...
            "FontWeight", "bold", "FontSize", 7, "FontName", "Times New Roman");
    end
end
end

function applyMaxHighlights(ax, displayMat, displaySem, mode, eligibleMask)
if nargin < 5 || isempty(eligibleMask)
    eligibleMask = true(size(displayMat));
end
finiteMask = isfinite(displayMat) & eligibleMask;
finiteVals = displayMat(finiteMask);
if isempty(finiteVals)
    return;
end

vMax = max(finiteVals);
maxColor = [0.1 0.45 0.85];
color95 = [0.78 0.86 0.98];
color99 = [0.28 0.52 0.82];

[maxY, maxX] = find(displayMat == vMax, 1, "first");
semMax = nan;
if ~isempty(displaySem) && isfinite(displaySem(maxY, maxX))
    semMax = displaySem(maxY, maxX);
end

[ny, nx] = size(displayMat);
maxMask = finiteMask & (displayMat == vMax);

if mode == "maxnondiff9599"
    z95 = 1.96;
    z99 = norminv(1 - 0.01 / 2);
    mask99 = false(ny, nx);
    mask95 = false(ny, nx);
    for yi = 1:ny
        for xi = 1:nx
            if ~finiteMask(yi, xi) || maxMask(yi, xi)
                continue;
            end
            semVal = nan;
            if ~isempty(displaySem) && isfinite(displaySem(yi, xi))
                semVal = displaySem(yi, xi);
            end
            tier = nondiffTier(displayMat(yi, xi), semVal, vMax, semMax, z95, z99);
            if tier == "99"
                mask99(yi, xi) = true;
            elseif tier == "95"
                mask95(yi, xi) = true;
            end
        end
    end
    drawHighlightRegionEdges(ax, mask99, color95, 1.5);
    drawHighlightRegionEdges(ax, mask95, color99, 1.8);
end

drawHighlightRegionEdges(ax, maxMask, maxColor, 2.2);
text(ax, maxX, maxY - 0.38, "MAX", "Color", maxColor, ...
    "HorizontalAlignment", "center", "VerticalAlignment", "bottom", ...
    "FontWeight", "bold", "FontSize", 8, "FontName", "Times New Roman");

end

function drawHighlightRegionEdges(ax, mask, edgeColor, lineWidth, lineStyle, occupied)
if nargin < 5 || isempty(lineStyle)
    lineStyle = "-";
end
if nargin < 6
    occupied = [];
end
if isempty(mask) || ~any(mask(:))
    return;
end

[ny, nx] = size(mask);
for yi = 1:ny
    for xi = 1:nx
        if ~mask(yi, xi)
            continue;
        end
        if yi == 1 || ~mask(yi - 1, xi)
            drawEdgeIfFree(ax, sprintf("H_%d_%d", yi - 1, xi), ...
                insetBoundaryCoords([xi - 0.5, xi + 0.5], nx), ...
                insetBoundaryCoords([yi - 0.5, yi - 0.5], ny), ...
                edgeColor, lineWidth, lineStyle, occupied);
        end
        if yi == ny || ~mask(yi + 1, xi)
            drawEdgeIfFree(ax, sprintf("H_%d_%d", yi, xi), ...
                insetBoundaryCoords([xi - 0.5, xi + 0.5], nx), ...
                insetBoundaryCoords([yi + 0.5, yi + 0.5], ny), ...
                edgeColor, lineWidth, lineStyle, occupied);
        end
        if xi == 1 || ~mask(yi, xi - 1)
            drawEdgeIfFree(ax, sprintf("V_%d_%d", yi, xi - 1), ...
                insetBoundaryCoords([xi - 0.5, xi - 0.5], nx), ...
                insetBoundaryCoords([yi - 0.5, yi + 0.5], ny), ...
                edgeColor, lineWidth, lineStyle, occupied);
        end
        if xi == nx || ~mask(yi, xi + 1)
            drawEdgeIfFree(ax, sprintf("V_%d_%d", yi, xi), ...
                insetBoundaryCoords([xi + 0.5, xi + 0.5], nx), ...
                insetBoundaryCoords([yi - 0.5, yi + 0.5], ny), ...
                edgeColor, lineWidth, lineStyle, occupied);
        end
    end
end

end

function coords = insetBoundaryCoords(coords, nCells)
%insetBoundaryCoords 軸境界（黒い外枠）と重なる座標を内側へオフセットして視認性を保つ
inset = 0.06;
coords(coords <= 0.5) = 0.5 + inset;
coords(coords >= nCells + 0.5) = nCells + 0.5 - inset;
end

function drawEdgeIfFree(ax, edgeKey, xData, yData, edgeColor, lineWidth, lineStyle, occupied)
%drawEdgeIfFree 既に上位グループが占有する辺なら描かない
% 注意: containers.Map は要素数 0 で isempty が true になるため isa で判定する
hasMap = isa(occupied, "containers.Map");
if hasMap && isKey(occupied, edgeKey)
    return;
end
line(ax, xData, yData, "Color", edgeColor, ...
    "LineWidth", lineWidth, "LineStyle", lineStyle);
if hasMap
    occupied(edgeKey) = true; %#ok<NASGU>
end
end

function paperCfg = resolvePaperTypography(cfg)
if nargin < 1 || isempty(cfg) || ~isfield(cfg, "paper")
    cfg = PaperStudyConfig();
end
paperCfg = cfg.paper;
end

function styleCfg = resolveHeatmapStyleCfg(cfg, cellFontSize)
if nargin < 1 || isempty(cfg) || ~isstruct(cfg) || ~isfield(cfg, "paper")
    styleCfg = PaperStudyConfig();
else
    styleCfg = cfg;
end
styleCfg.paper.fontSizeBase = cellFontSize;
end

function tier = nondiffTier(meanVal, semVal, meanMin, semMin, z95, z99)
tier = "none";
if ~isfinite(meanVal) || ~isfinite(meanMin)
    return;
end
if ~isfinite(semVal)
    semVal = 0;
end
if ~isfinite(semMin)
    semMin = 0;
end
diffAbs = abs(meanVal - meanMin);
seCombined = sqrt(semVal^2 + semMin^2);
if seCombined == 0
    if diffAbs < 1e-12
        tier = "95";
    end
    return;
end
if diffAbs <= z95 * seCombined
    tier = "95";
elseif diffAbs <= z99 * seCombined
    tier = "99";
end
end
