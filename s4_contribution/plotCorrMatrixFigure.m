function outPath = plotCorrMatrixFigure(mat, names, cfg, outPath, cbarLabel)
%plotCorrMatrixFigure Spearman/Pearson predictor correlation matrix figure

if nargin < 5 || isempty(cbarLabel)
    cbarLabel = "Spearman $\rho$";
end

dpi = 300;
if isfield(cfg, "analysis") && isfield(cfg.analysis, "figureDpi")
    dpi = cfg.analysis.figureDpi;
end
fontName = "Times New Roman";
fontSizeCell = 8;
fontSizeVarLabel = 10.5;
if isfield(cfg, "paper")
    if isfield(cfg.paper, "fontName")
        fontName = cfg.paper.fontName;
    end
    if isfield(cfg.paper, "fontSizeLegend")
        fontSizeCell = cfg.paper.fontSizeLegend;
    end
    if isfield(cfg.paper, "fontSizeBase")
        fontSizeVarLabel = cfg.paper.fontSizeBase;
    end
end
if fontSizeVarLabel <= fontSizeCell
    fontSizeVarLabel = fontSizeCell + 2;
end

n = size(mat, 1);
tickLabels = cellstr(string(names(:)));
matPlot = flipud(mat);
rowTickLabels = tickLabels(end:-1:1);

fig = figure("Color", "w", "Position", [80 80 720 640], "Visible", "off");
ax = axes(fig);
imagesc(ax, 1:n, 1:n, matPlot, "AlphaData", isfinite(matPlot));
set(ax, "YDir", "normal");
fullMap = redblueColormapLocal();
half = floor(size(fullMap, 1) / 2);
colormap(ax, fullMap(half:end, :));
caxis(ax, [0, 1]);
cb = colorbar(ax);
cb.Label.String = cbarLabel;
cb.Label.FontName = fontName;
cb.Label.FontSize = fontSizeCell;
cb.Label.Interpreter = "latex";
cb.Ticks = 0:0.2:1;
cb.TickLabelInterpreter = "latex";
cb.FontName = fontName;
cb.FontSize = fontSizeCell;

xticks(ax, 1:n);
yticks(ax, 1:n);
xticklabels(ax, {});
yticklabels(ax, {});
set(ax, "FontName", fontName, "FontSize", fontSizeCell);
title(ax, "Predictor correlation structure", ...
    "FontName", fontName, "FontSize", fontSizeCell, "Interpreter", "none");
xlim(ax, [0.5, n + 0.5]);
ylim(ax, [0.5, n + 0.5]);
ax.XAxis.TickLength = [0 0];
ax.YAxis.TickLength = [0 0];

for i = 1:n
    text(ax, i, 0.18, tickLabels{i}, ...
        "HorizontalAlignment", "right", "VerticalAlignment", "top", ...
        "Rotation", 45, "FontSize", fontSizeVarLabel, "FontName", fontName, ...
        "Interpreter", "latex", "Clipping", "off");
    text(ax, 0.35, i, rowTickLabels{i}, ...
        "HorizontalAlignment", "right", "VerticalAlignment", "middle", ...
        "FontSize", fontSizeVarLabel, "FontName", fontName, ...
        "Interpreter", "latex", "Clipping", "off");
end

for yi = 1:n
    for xi = 1:n
        v = matPlot(yi, xi);
        if ~isfinite(v)
            continue;
        end
        txtColor = "w";
        if v < 0.55
            txtColor = "k";
        end
        text(ax, xi, yi, sprintf("%.2f", v), ...
            "HorizontalAlignment", "center", "VerticalAlignment", "middle", ...
            "FontSize", fontSizeCell, "FontName", fontName, "Color", txtColor, ...
            "Interpreter", "none");
    end
end

ax.Position = [0.18 0.18 0.68 0.72];
exportPaperFigure(fig, outPath, "Resolution", dpi);
end

function cmap = redblueColormapLocal()
n = 256;
half = floor(n / 2);
r1 = linspace(0.2, 1, half)';
g1 = linspace(0.2, 1, half)';
b1 = ones(half, 1);
r2 = ones(n - half, 1);
g2 = linspace(1, 0.2, n - half)';
b2 = linspace(1, 0.2, n - half)';
cmap = [r1, g1, b1; r2, g2, b2];
end
