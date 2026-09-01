function plotKrMethodHeatmaps(summaryTable, outDir, cfg, opts)
%plotKrMethodHeatmaps Q1 方式グリッド MAE / 相対誤差ヒートマップ

if nargin < 4 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "figPrefix") || strlength(string(opts.figPrefix)) == 0
    opts.figPrefix = "fig2";
end
if ~isfield(opts, "globalMaeClim")
    opts.globalMaeClim = [];
end
if ~isfield(opts, "globalRelErrorClim")
    opts.globalRelErrorClim = [];
end
if ~isfield(opts, "krVariant") || strlength(string(opts.krVariant)) == 0
    opts.krVariant = string(cfg.deploy.krVariant);
end
if ~isfield(opts, "pairTable")
    opts.pairTable = [];
end

methodTypes = activeKrMethodTypes(cfg);
prefixByType = struct( ...
    "percent_yield", "yield_pct", ...
    "force_abs", "force_abs", ...
    "force_trailing", "force_trail");

if isempty(opts.globalMaeClim) || numel(opts.globalMaeClim) ~= 2
    opts.globalMaeClim = computeGlobalMaeHeatmapClim(summaryTable, [], cfg);
end
if isempty(opts.globalRelErrorClim) || numel(opts.globalRelErrorClim) ~= 2
    opts.globalRelErrorClim = computeGlobalRelErrorHeatmapClim(summaryTable, [], cfg);
end

subAll = summaryTable;
if ismember("variant", subAll.Properties.VariableNames)
    subAll = subAll(string(subAll.variant) == opts.krVariant, :);
end

refInfo = resolveKrHeatmapReference(opts.pairTable, subAll, "mae_loocv");

metricDefs = {
    struct("suffix", "mae_heatmap", "valueField", "mae_loocv", "semField", "mae_loocv_sem", ...
        "titleMetric", "MAE", "cbar", "LOOCV MAE [N]", "clim", opts.globalMaeClim, ...
        "scaleMode", "abs", "highlight", "minNondiffFdr", "useWilcoxonMask", true)
    struct("suffix", "rel_error_heatmap", "valueField", "relativeError_loocv", ...
        "semField", "relativeError_loocv_sem", "titleMetric", "Relative error", ...
        "cbar", "LOOCV relative error [%]", "clim", opts.globalRelErrorClim, ...
        "scaleMode", "pct", "highlight", "minNondiffFdr", "useWilcoxonMask", true)};

variantTag = char(opts.krVariant);

for mi = 1:numel(metricDefs)
    metric = metricDefs{mi};
    if ~ismember(metric.valueField, subAll.Properties.VariableNames)
        continue;
    end
    for ti = 1:numel(methodTypes)
        mt = methodTypes(ti);
        prefix = prefixByType.(char(mt));
        sub = subAll(string(subAll.methodType) == mt, :);
        if isempty(sub)
            continue;
        end
        semField = metric.semField;
        if ~ismember(semField, sub.Properties.VariableNames)
            semField = "";
        end
        [valueMat, semMat, starts, widths, ~] = buildKrGridMatrices( ...
            sub, metric.valueField, semField, mt);
        if isempty(valueMat) || all(isnan(valueMat(:)))
            continue;
        end
        nondiffMask = [];
        if metric.useWilcoxonMask && strlength(string(refInfo.methodKey)) > 0
            nondiffMask = buildKrWilcoxonNondiffMask(opts.pairTable, mt, refInfo.methodKey, ...
                struct("referenceVariant", refInfo.variant));
        end
        layout = resolveKrHeatmapLayout(prefix, starts, widths);
        outPath = fullfile(outDir, opts.figPrefix + "_" + prefix + "_" + metric.suffix + ".png");
        plotKrGridHeatmap(valueMat, semMat, starts, widths, ...
            title=sprintf("%s %s heatmap (%s, %s)", prefix, metric.titleMetric, variantTag, "LOOCV"), ...
            outPath=outPath, cfg=cfg, clim=metric.clim, colorbarLabel=metric.cbar, ...
            highlightMode=metric.highlight, scaleMode=metric.scaleMode, showSem=true, ...
            figureSize=layout.figSize, compactText=layout.compactText, ...
            xLabel=layout.xLabel, yLabel=layout.yLabel, nondiffMask=nondiffMask);
    end
end

end
