function plotQ7DesignAlphaFigures(designSummary, designTable, outDir, cfg)
%plotQ7DesignAlphaFigures Design トラック固有図（α_design ヒートマップ）

if nargin < 4
    cfg = PaperStudyConfig();
end
if ~cfg.figures.enabled || isempty(designSummary)
    return;
end

methodTypes = ["force_abs", "force_trailing"];
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");
aTag = "adesign";

extraMetrics = {
    struct("name", "alpha_design", "field", "alphaDesign", "title", "Design alpha", ...
            "cbar", "\\alpha_{0.95}", "scale", "abs", "highlight", "none")
    };

subBase = designSummary;
if ~ismember("alphaDesign", subBase.Properties.VariableNames) && ismember("alpha", subBase.Properties.VariableNames)
    subBase.alphaDesign = subBase.alpha;
end
if ~ismember("alphaDesign", subBase.Properties.VariableNames) && ~isempty(designTable)
    subBase = joinDesignFields(subBase, designTable, ["alphaDesign"]);
end

for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    prefix = prefixByType.(char(mt));
    sub = subBase(string(subBase.methodType) == mt, :);
    if isempty(sub)
        continue;
    end
    for mi = 1:numel(extraMetrics)
        m = extraMetrics{mi};
        if ~ismember(m.field, sub.Properties.VariableNames)
            continue;
        end
        [valueMat, ~, starts, widths, ~] = buildKrGridMatrices(sub, m.field, "", mt);
        if isempty(valueMat) || all(isnan(valueMat(:)))
            continue;
        end
        layout = resolveKrHeatmapLayout(prefix, starts, widths);
        outPath = fullfile(outDir, "fig7x_" + m.name + "_" + prefix + "_" + aTag + ".png");
        plotKrGridHeatmap(valueMat, [], starts, widths, ...
            title=sprintf("%s (%s, design-\\alpha)", m.title, prefix), ...
            outPath=outPath, cfg=cfg, colorbarLabel=m.cbar, ...
            highlightMode=m.highlight, scaleMode=m.scale, ...
            showSem=false, figureSize=layout.figSize, compactText=layout.compactText, ...
            xLabel=layout.xLabel, yLabel=layout.yLabel, valueDecimals=2);
    end
end
end

function sub = joinDesignFields(sub, designTable, fields)
keys = string(sub.krMethodKey);
for fi = 1:numel(fields)
    f = fields(fi);
    if ~ismember(f, designTable.Properties.VariableNames)
        continue;
    end
    vals = nan(height(sub), 1);
    for i = 1:height(sub)
        idx = find(string(designTable.krMethodKey) == keys(i), 1);
        if ~isempty(idx)
            vals(i) = designTable.(f)(idx);
        end
    end
    sub.(f) = vals;
end
end
