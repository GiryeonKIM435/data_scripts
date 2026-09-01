function plotMeanMaeCiComparison(compTbl, outPath, cfg, plotOpts)
%plotMeanMaeCiComparison 各条件の平均MAEと95%CIを並列表示
%
% compTbl: compareModelsToReference 出力

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 4 || isempty(plotOpts)
    plotOpts = struct();
end

labels = defaultDisplayLabels(compTbl.model);
n = height(compTbl);
x = 1:n;
offset = 0.16;
xModel = x - offset;
xRef = x + offset;

figW = max(700, 130 * n);
fig = figure("Color", "w", "Position", [80 80 figW 540], "Visible", "off");
ax = axes(fig);
hold(ax, "on");

modelMean = compTbl.meanMaeModel;
modelLo = compTbl.ciMeanMaeModelLo;
modelHi = compTbl.ciMeanMaeModelHi;
refMean = compTbl.meanMaeReference;
refLo = compTbl.ciMeanMaeReferenceLo;
refHi = compTbl.ciMeanMaeReferenceHi;

errorbar(ax, xModel, modelMean, modelMean - modelLo, modelHi - modelMean, "o", ...
    "LineWidth", 1.2, "Color", [0.12 0.47 0.71], "MarkerFaceColor", [0.12 0.47 0.71], ...
    "CapSize", 8, "DisplayName", "model");
errorbar(ax, xRef, refMean, refMean - refLo, refHi - refMean, "s", ...
    "LineWidth", 1.2, "Color", [0.85 0.33 0.10], "MarkerFaceColor", [0.85 0.33 0.10], ...
    "CapSize", 8, "DisplayName", "reference");

for i = 1:n
    if isfield(compTbl, "isMeanCiSeparated") && logical(compTbl.isMeanCiSeparated(i))
        yTop = max([modelHi(i), refHi(i)]);
        text(ax, x(i), yTop + 0.15, "CI separated", ...
            "HorizontalAlignment", "center", "VerticalAlignment", "bottom", ...
            "FontSize", 8, "Color", [0.55 0.10 0.10]);
    end
end

set(ax, "XTick", x, "XTickLabel", cellstr(labels));
xtickangle(ax, 0);
ylabel(ax, "Mean MAE [N]");
if isfield(plotOpts, "title") && strlength(string(plotOpts.title)) > 0
    title(ax, char(plotOpts.title));
end
grid(ax, "on");
legend(ax, "Location", "best");

if isfield(plotOpts, "ylabelNote") && strlength(string(plotOpts.ylabelNote)) > 0
    xlabel(ax, char(plotOpts.ylabelNote));
end

exportPaperFigure(fig, outPath, "Resolution", cfg.analysis.figureDpi);
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
