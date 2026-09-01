function plotPairedDeltaMaeForest(compTbl, outPath, cfg, plotOpts)
%plotPairedDeltaMaeForest ペア ΔMAE 森林プロット（縦軸 ΔMAE、bootstrap p）
%
% compTbl: compareModelsToReference 出力（deltaMae, ciDeltaMaeLo/Hi, pBootstrap）
% plotOpts.title, plotOpts.ylabelNote, plotOpts.displayLabels (optional)

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 4 || isempty(plotOpts)
    plotOpts = struct();
end

if isfield(plotOpts, "displayLabels") && ~isempty(plotOpts.displayLabels)
    labels = string(plotOpts.displayLabels(:));
else
    labels = defaultDisplayLabels(compTbl.model);
end

deltas = compTbl.deltaMae;
ciLo = compTbl.ciDeltaMaeLo;
ciHi = compTbl.ciDeltaMaeHi;
pVals = compTbl.pBootstrap;
if ismember("pWilcoxon", compTbl.Properties.VariableNames)
    pVals = compTbl.pWilcoxon;
end
n = numel(labels);

figW = max(640, 120 * n);
fig = figure("Color", "w", "Position", [80 80 figW 520], "Visible", "off");
xPos = 1:n;
hold on;
errorbar(xPos, deltas, deltas - ciLo, ciHi - deltas, "o", ...
    "LineWidth", 1.2, "MarkerSize", 7, "CapSize", 10);
set(gca, "XTick", xPos, "XTickLabel", cellstr(labels));
yline(0, "k--");

yVals = [deltas; ciLo; ciHi];
yRange = max(yVals) - min(yVals);
if ~isfinite(yRange) || yRange == 0
    yRange = max(abs(yVals), [], "omitnan");
end
yPad = 0.12 * max(yRange, 0.5);
yTop = max(yVals);
for i = 1:n
    yText = max(deltas(i), ciHi(i)) + yPad;
    text(xPos(i), yText, char(formatPForDisplay(pVals(i))), ...
        "HorizontalAlignment", "center", "FontSize", 9, "VerticalAlignment", "bottom");
    yTop = max(yTop, yText);
end
ylim([min(yVals) - yPad, yTop + yPad]);

ylabel("\DeltaMAE [N]");
if isfield(plotOpts, "ylabelNote") && strlength(string(plotOpts.ylabelNote)) > 0
    ylabel(sprintf("\\DeltaMAE [N] (%s)", char(plotOpts.ylabelNote)));
end
if isfield(plotOpts, "title") && strlength(string(plotOpts.title)) > 0
    title(char(plotOpts.title));
end
grid on;

dpi = cfg.analysis.figureDpi;
if isfield(plotOpts, "dpi") && ~isempty(plotOpts.dpi)
    dpi = plotOpts.dpi;
end
exportPaperFigure(fig, outPath, "Resolution", dpi);
end

function labels = defaultDisplayLabels(modelNames)
modelNames = string(modelNames(:));
labels = strings(size(modelNames));
for i = 1:numel(modelNames)
    name = modelNames(i);
    if name == "M3_kr_burgers"
        labels(i) = "M3";
    elseif startsWith(name, "M1_plus_")
        labels(i) = "+" + extractAfter(name, "M1_plus_");
    elseif startsWith(name, "M3_minus_")
        labels(i) = "-" + extractAfter(name, "M3_minus_");
    else
        labels(i) = name;
    end
end
end
