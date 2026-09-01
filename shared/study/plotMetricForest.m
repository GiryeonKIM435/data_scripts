function plotMetricForest(summaryTable, metricName, outPath, cfg, plotOpts)
%plotMetricForest LOOCV 指標の森林プロット（CI 付き）

if nargin < 4 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 5 || isempty(plotOpts)
    plotOpts = struct();
end

metricName = string(metricName);
col = string(metricName) + cfg.metrics.loocvSuffix;
ciLoCol = col + "_ci_lo";
ciHiCol = col + "_ci_hi";

if ~ismember(col, summaryTable.Properties.VariableNames)
    error("plotMetricForest:MissingColumn", "列がありません: %s", col);
end

labels = summaryTable.label;
vals = summaryTable.(col);
hasCi = ismember(ciLoCol, summaryTable.Properties.VariableNames) && ...
    ismember(ciHiCol, summaryTable.Properties.VariableNames);
if hasCi
    ciLo = summaryTable.(ciLoCol);
    ciHi = summaryTable.(ciHiCol);
else
    ciLo = vals;
    ciHi = vals;
end

n = height(summaryTable);
fig = figure("Color", "w", "Position", [80 80 900 max(420, 28 * n)], "Visible", "off");
yPos = 1:n;
if hasCi
    errorbar(vals, yPos, vals - ciLo, ciHi - vals, "horizontal", "o", ...
        "LineWidth", 1.2, "MarkerSize", 6, "CapSize", 8);
else
    plot(vals, yPos, "o", "LineWidth", 1.2, "MarkerSize", 6);
end
set(gca, "YDir", "reverse", "YTick", yPos, "YTickLabel", labels);

[xLabel, titleMetric] = metricLabels(metricName);
xlabel(xLabel);
if isfield(plotOpts, "titlePrefix") && strlength(string(plotOpts.titlePrefix)) > 0
    titlePrefix = char(plotOpts.titlePrefix);
else
    titlePrefix = "kr methods LOOCV";
end
title(sprintf("%s %s (n=%d)", titlePrefix, titleMetric, summaryTable.nUsed(1)));
grid on;

dpi = cfg.analysis.figureDpi;
if isfield(plotOpts, "dpi") && ~isempty(plotOpts.dpi)
    dpi = plotOpts.dpi;
end
exportPaperFigure(fig, outPath, "Resolution", dpi);

end
function [xLabel, titleMetric] = metricLabels(metricName)
switch metricName
    case "mae"
        xLabel = "LOOCV MAE [N]";
        titleMetric = "MAE";
    case "rmse"
        xLabel = "LOOCV RMSE [N]";
        titleMetric = "RMSE";
    case "r2"
        xLabel = "LOOCV R^2";
        titleMetric = "R2";
    otherwise
        xLabel = char(metricName);
        titleMetric = char(metricName);
end
end
