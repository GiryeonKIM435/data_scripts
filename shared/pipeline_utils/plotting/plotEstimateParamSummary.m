function plotEstimateParamSummary(cfg, summaryTable, metadata)
%PLOTESTIMATEPARAMSUMMARY 推定パラメータ要約の figure 出力

if nargin < 3
    metadata = struct("nBurgersSuccess", NaN);
end
if ~cfg.figures.enabled
    return;
end

pu = plotUtils();
figRoot = fullfile(cfg.out.estimate, "figures", "summary");
pu.ensureDir(figRoot);

nCohort = metadata.nBurgersSuccess;
layoutTitle = sprintf("Estimate parameters (Jeffreys success, n=%d)", nCohort);

cats = unique(summaryTable.category, "stable");
nCat = numel(cats);
nCols = min(3, nCat);
nRows = ceil(nCat / nCols);

fig1 = pu.newOffFigure("estimate mean sd bars", [60 60 320 * nCols 280 * nRows]);
t1 = tiledlayout(fig1, nRows, nCols, "TileSpacing", "compact", "Padding", "compact");
title(t1, layoutTitle);

for ci = 1:nCat
    ax = nexttile(t1);
    rows = summaryTable.category == cats(ci);
    sub = summaryTable(rows, :);
    sub = sub(sub.n > 0, :);
    if isempty(sub)
        axis(ax, "off");
        title(ax, char(cats(ci)));
        continue;
    end
    labels = sub.parameter + " [" + sub.unit + "]";
    pu.plotBarHorizontalWithSe(sub.mean, sub.std, labels, "mean", char(cats(ci)), ax);
end
pu.saveStageFigure(fig1, figRoot, "01_mean_sd_bars", cfg.figures);

fig2 = pu.newOffFigure("estimate summary table", [60 60 1100 520]);
plotSummaryTableFigure(fig2, summaryTable, layoutTitle);
pu.saveStageFigure(fig2, figRoot, "02_summary_table", cfg.figures);

end

function plotSummaryTableFigure(fig, summaryTable, titleStr)
rows = height(summaryTable);
headers = ["category", "parameter", "unit", "n", "mean", "std", "min", "max"];
tableData = strings(rows, numel(headers));
for r = 1:rows
    tableData(r, 1) = summaryTable.category(r);
    tableData(r, 2) = summaryTable.parameter(r);
    tableData(r, 3) = summaryTable.unit(r);
    tableData(r, 4) = string(summaryTable.n(r));
    tableData(r, 5) = formatNum(summaryTable.mean(r));
    tableData(r, 6) = formatNum(summaryTable.std(r));
    tableData(r, 7) = formatNum(summaryTable.min(r));
    tableData(r, 8) = formatNum(summaryTable.max(r));
end

ax = axes(fig, "Position", [0.04 0.04 0.92 0.86], "Visible", "off");
title(ax, titleStr, "FontWeight", "bold", "FontSize", 12);
nCols = numel(headers);
nTableRows = rows + 1;
colFrac = [0.14, 0.14, 0.10, 0.06, 0.14, 0.14, 0.14, 0.14];
colFrac = colFrac / sum(colFrac);
xEdges = [0, cumsum(colFrac)];
yTop = 0.98;
rowH = 0.92 / nTableRows;

hold(ax, "on");
for c = 1:nCols
    plot(ax, [xEdges(c) xEdges(c)], [0.02 yTop], "Color", [0.75 0.75 0.75]);
end
plot(ax, [0 1], [0.02 yTop], "Color", [0.75 0.75 0.75]);

for r = 1:nTableRows
    y = yTop - r * rowH;
    plot(ax, [0 1], [y y], "Color", [0.75 0.75 0.75]);
    if r == 1
        faceColor = [0.90 0.93 0.98];
        fontWeight = "bold";
        rowCells = headers;
    else
        if mod(r, 2) == 0
            faceColor = [0.98 0.98 0.98];
        else
            faceColor = [1 1 1];
        end
        fontWeight = "normal";
        rowCells = tableData(r - 1, :);
    end
    for c = 1:nCols
        x = xEdges(c) + 0.01;
        rectangle(ax, "Position", [xEdges(c), y, colFrac(c), rowH], ...
            "FaceColor", faceColor, "EdgeColor", "none");
        text(ax, x, y + rowH * 0.55, char(rowCells(c)), ...
            "FontSize", 10, "FontWeight", fontWeight, ...
            "VerticalAlignment", "middle", "Interpreter", "none");
    end
end
xlim(ax, [0 1]);
ylim(ax, [0 1]);
hold(ax, "off");
end

function s = formatNum(x)
if ~isfinite(x)
    s = "NA";
else
    s = string(sprintf("%.4g", x));
end
end
