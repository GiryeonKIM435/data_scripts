function exportPaperTablePreviewFigure(tbl, pngPath, caption, cfg)
%nRows = height(tbl);
if nargin < 4 || isempty(cfg)
    cfg = PaperStudyConfig();
end
fontName = cfg.paper.fontName;
baseSz = cfg.paper.fontSizeBase;
titleSz = cfg.paper.fontSizeTitle;

layout = paperTableLayout(tbl);
nCols = width(tbl);
nRows = height(tbl);
colNames = layout.colNames;
xEdges = computeTableXEdges(layout.colWeights);

charPx = max(6.5, baseSz * 0.62);
figW = max(420, round(sum(layout.colWeights) * charPx + 120));
figH = max(220, round(28 * (nRows + 3.5) + 40));
fig = figure("Color", "w", "Position", [80 80 figW figH], "Visible", "off");
ax = axes(fig, "Position", [0.04 0.06 0.92 0.90]);
axis(ax, "off");
hold(ax, "on");

title(ax, caption, "Interpreter", "none", "FontWeight", "bold", ...
    "FontSize", titleSz, "FontName", fontName);

yTop = 0.94;
rowH = min(0.09, 0.82 / (nRows + 1.2));
headerY = yTop;

for c = 1:nCols
    x = columnTextX(xEdges, c, "center");
    text(ax, x, headerY, colNames(c), ...
        "HorizontalAlignment", "center", "FontWeight", "bold", ...
        "FontSize", baseSz, "FontName", fontName);
end
plot(ax, [xEdges(1) xEdges(end)], [headerY - rowH * 0.35, headerY - rowH * 0.35], ...
    "k-", "LineWidth", 0.8);

for r = 1:nRows
    yRow = headerY - rowH * (r + 0.5);
    for c = 1:nCols
        txt = layout.cellText(r, c);
        align = layout.colAlign(c);
        x = columnTextX(xEdges, c, align);
        text(ax, x, yRow, txt, ...
            "HorizontalAlignment", align, "FontSize", baseSz, ...
            "FontName", fontName, "Interpreter", "none");
    end
end

exportPaperFigure(fig, pngPath, "Resolution", cfg.analysis.figureDpi);
end

function xEdges = computeTableXEdges(colWeights)
total = sum(colWeights);
if total <= 0
    xEdges = linspace(0.02, 0.98, numel(colWeights) + 1);
    return;
end
rel = colWeights / total;
xEdges = zeros(1, numel(colWeights) + 1);
xEdges(1) = 0.02;
for c = 1:numel(colWeights)
    xEdges(c + 1) = xEdges(c) + 0.96 * rel(c);
end
xEdges(end) = min(0.98, xEdges(end));
end

function x = columnTextX(xEdges, c, align)
pad = 0.008;
switch align
    case "right"
        x = xEdges(c + 1) - pad;
    case "left"
        x = xEdges(c) + pad;
    otherwise
        x = mean(xEdges(c:c + 1));
end
end
