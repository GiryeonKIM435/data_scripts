function plotStreamingDeployFigures(summaryTable, alphaValues, outDir, cfg, opts)
%plotStreamingDeployFigures Q3 デプロイ結果ヒートマップ群

if nargin < 5
    opts = struct();
end
if ~isfield(opts, "figPrefix")
    opts.figPrefix = "fig3";
end
if ~isfield(opts, "cleanupLegacy")
    opts.cleanupLegacy = strcmp(opts.figPrefix, "fig3");
end
if ~isfield(opts, "q1SummaryTable")
    opts.q1SummaryTable = loadQ1SummaryTable(cfg);
end
if ~isfield(opts, "globalRelErrorClim")
    opts.globalRelErrorClim = [];
end
if ~isfield(opts, "globalMaeClim")
    opts.globalMaeClim = computeGlobalMaeHeatmapClim(opts.q1SummaryTable, summaryTable, cfg);
end
if isempty(opts.globalRelErrorClim) || numel(opts.globalRelErrorClim) ~= 2
    opts.globalRelErrorClim = computeGlobalRelErrorHeatmapClim(opts.q1SummaryTable, summaryTable, cfg);
end
if ~isfield(opts, "globalStopR2Clim") || isempty(opts.globalStopR2Clim) || numel(opts.globalStopR2Clim) ~= 2
    opts.globalStopR2Clim = computeGlobalStopR2HeatmapClim(summaryTable, cfg);
end
if ~isfield(opts, "pairTable")
    opts.pairTable = [];
end

if opts.cleanupLegacy
    cleanupDeprecatedQ3Figures(outDir, alphaValues);
end

methodTypes = activeKrMethodTypes(cfg);
prefixByType = struct( ...
    "percent_yield", "yield_pct", ...
    "force_abs", "force_abs", ...
    "force_trailing", "force_trail");
if opts.figPrefix == "fig5"
    cleanupDeprecatedFig5SafeStopErrorFigures(outDir, alphaValues, methodTypes, prefixByType);
end
metricDefs = {
    struct("figTag", "b", "valueField", "safeStopRate", "semField", "", ...
        "name", "safe_stop_rate", "titleName", "Safe-stop rate", "scale", "pct", ...
        "highlight", "none", "cbar", "Safe-stop rate [%]", "showSem", false, ...
        "useGlobalMaeClim", false, "useGlobalRelErrorClim", false, "useGlobalStopR2Clim", false)
    struct("figTag", "c", "valueField", "stopMae_success_bootMean_b5000", "semField", "stopMae_success_ci_halfwidth_b5000", ...
        "name", "stop_mae", "titleName", "Stop MAE", "scale", "abs", ...
        "highlight", "minNondiffFdr", "cbar", "Stop MAE [N]", "showSem", true, ...
        "useGlobalMaeClim", true, "useGlobalRelErrorClim", false, "useGlobalStopR2Clim", false, ...
        "useWilcoxonMask", true)
    struct("figTag", "f", "valueField", "stopR2_success", "semField", "", ...
        "name", "stop_r2", "titleName", "Stop R^2", "scale", "abs", ...
        "highlight", "maxNondiff9599", "cbar", "Stop R^2", "showSem", false, ...
        "useGlobalMaeClim", false, "useGlobalRelErrorClim", false, "useGlobalStopR2Clim", true)
    struct("figTag", "d", "valueField", "relativeStopError_success_bootMean_b5000", ...
        "semField", "relativeStopError_success_ci_halfwidth_b5000", "name", "rel_stop_error", ...
        "titleName", "Relative stop error", "scale", "pct", ...
        "highlight", "minNondiff9599", "cbar", "Relative stop error [%]", "showSem", true, ...
        "useGlobalMaeClim", false, "useGlobalRelErrorClim", true, "useGlobalStopR2Clim", false, ...
        "safeStopMin", nan, "titleSuffix", "")
    struct("figTag", "d", "valueField", "stopMae_success_bootMean_b5000", ...
        "semField", "stopMae_success_ci_halfwidth_b5000", "name", "stop_error_safe100", ...
        "titleName", "Stop error", "scale", "abs", ...
        "highlight", "minNondiffFdr", "cbar", "Stop MAE [N]", "showSem", true, ...
        "useGlobalMaeClim", true, "useGlobalRelErrorClim", false, "useGlobalStopR2Clim", false, ...
        "safeStopMin", 1.0, "titleSuffix", ", safe-stop=100%", "useWilcoxonMask", true)
    struct("figTag", "d", "valueField", "stopMae_success_bootMean_b5000", ...
        "semField", "stopMae_success_ci_halfwidth_b5000", "name", "stop_error_safe98", ...
        "titleName", "Stop error", "scale", "abs", ...
        "highlight", "minNondiffFdr", "cbar", "Stop MAE [N]", "showSem", true, ...
        "useGlobalMaeClim", true, "useGlobalRelErrorClim", false, "useGlobalStopR2Clim", false, ...
        "safeStopMin", 0.98, "titleSuffix", ", safe-stop>=98%", "useWilcoxonMask", true)};

if isfield(opts, "allowedMetricNames") && ~isempty(opts.allowedMetricNames)
    allowed = string(opts.allowedMetricNames(:));
    keep = false(numel(metricDefs), 1);
    for mi = 1:numel(metricDefs)
        keep(mi) = any(string(metricDefs{mi}.name) == allowed);
    end
    metricDefs = metricDefs(keep);
end

for mi = 1:numel(metricDefs)
    metric = metricDefs{mi};
    if ~ismember(metric.valueField, summaryTable.Properties.VariableNames)
        continue;
    end
    if strcmp(metric.valueField, "stopR2_success") ...
            && ~ismember("stopR2_success", summaryTable.Properties.VariableNames)
        continue;
    end
    if metric.useGlobalMaeClim
        clim = opts.globalMaeClim;
    elseif isfield(metric, "useGlobalStopR2Clim") && metric.useGlobalStopR2Clim
        clim = opts.globalStopR2Clim;
    elseif metric.useGlobalRelErrorClim
        clim = opts.globalRelErrorClim;
    else
        clim = computeKrGridClim(summaryTable, alphaValues, methodTypes, ...
            metric.valueField, metric.scale);
    end
    for ai = 1:numel(alphaValues)
        alpha = alphaValues(ai);
        aTag = formatAlphaTag(alpha);
        for ti = 1:numel(methodTypes)
            mt = methodTypes(ti);
            prefix = prefixByType.(char(mt));
            sub = summaryTable(summaryTable.alpha == alpha ...
                & string(summaryTable.methodType) == mt, :);
            if isempty(sub)
                continue;
            end
            [valueMat, semMat, starts, widths, ~] = buildKrGridMatrices( ...
                sub, metric.valueField, metric.semField, mt);
            if isempty(valueMat) || all(isnan(valueMat(:)))
                continue;
            end
            if ~metric.showSem
                semMat = [];
            end
            eligibilityMask = [];
            if isfield(metric, "safeStopMin") && isfinite(metric.safeStopMin)
                [safeStopMat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "safeStopRate", "", mt);
                eligibilityMask = isfinite(safeStopMat) & (safeStopMat >= metric.safeStopMin);
            end
            titleSuffix = "";
            if isfield(metric, "titleSuffix")
                titleSuffix = char(metric.titleSuffix);
            end
            layout = resolveKrHeatmapLayout(prefix, starts, widths);
            outPath = fullfile(outDir, ...
                opts.figPrefix + metric.figTag + "_" + metric.name + "_" + prefix + "_" + aTag + ".png");
            nondiffMask = [];
            if isfield(metric, "useWilcoxonMask") && metric.useWilcoxonMask
                subAlpha = summaryTable(summaryTable.alpha == alpha, :);
                pairAlpha = opts.pairTable;
                if ~isempty(pairAlpha) && istable(pairAlpha) && ismember("alpha", pairAlpha.Properties.VariableNames)
                    pairAlpha = pairAlpha(pairAlpha.alpha == alpha, :);
                end
                refInfo = resolveKrHeatmapReference(pairAlpha, subAlpha, "stopMae_success");
                if strlength(string(refInfo.methodKey)) > 0
                    nondiffMask = buildKrWilcoxonNondiffMask(pairAlpha, mt, refInfo.methodKey, ...
                        struct("alpha", alpha, "referenceVariant", refInfo.variant));
                end
            end
            if isempty(eligibilityMask)
                plotKrGridHeatmap(valueMat, semMat, starts, widths, ...
                    title=sprintf("%s heatmap (%s, alpha=%.1f%s)", metric.titleName, prefix, alpha, titleSuffix), ...
                    outPath=outPath, cfg=cfg, clim=clim, colorbarLabel=metric.cbar, ...
                    highlightMode=metric.highlight, scaleMode=metric.scale, ...
                    showSem=metric.showSem, figureSize=layout.figSize, compactText=layout.compactText, ...
                    xLabel=layout.xLabel, yLabel=layout.yLabel, nondiffMask=nondiffMask);
            else
                plotKrGridHeatmap(valueMat, semMat, starts, widths, ...
                    title=sprintf("%s heatmap (%s, alpha=%.1f%s)", metric.titleName, prefix, alpha, titleSuffix), ...
                    outPath=outPath, cfg=cfg, clim=clim, colorbarLabel=metric.cbar, ...
                    highlightMode=metric.highlight, scaleMode=metric.scale, ...
                    showSem=metric.showSem, figureSize=layout.figSize, compactText=layout.compactText, ...
                    xLabel=layout.xLabel, yLabel=layout.yLabel, eligibilityMask=eligibilityMask, ...
                    nondiffMask=nondiffMask);
            end
        end
    end
end
end

function aTag = formatAlphaTag(alpha)
aTag = "a" + strrep(sprintf("%.1f", alpha), ".", "");
end

function cleanupDeprecatedFig5SafeStopErrorFigures(outDir, alphaValues, methodTypes, prefixByType)
legacyNames = ["rel_stop_error_safe100", "rel_stop_error_safe98"];
for ai = 1:numel(alphaValues)
    aTag = formatAlphaTag(alphaValues(ai));
    for ti = 1:numel(methodTypes)
        prefix = prefixByType.(char(methodTypes(ti)));
        for ni = 1:numel(legacyNames)
            for ext = [".png", ".fig"]
                fpath = fullfile(outDir, "fig5d_" + legacyNames(ni) + "_" + prefix + "_" + aTag + ext);
                if isfile(fpath)
                    delete(fpath);
                end
            end
        end
    end
end
end

function cleanupDeprecatedQ3Figures(outDir, alphaValues)
legacyPatterns = [
    "fig3a_integrated_practical_tradeoff_";
    "fig3b_fail_composition_";
    "fig3c_q1_vs_q3_mae_";
    "fig3d_warmup_cost_";
    "fig5d_practical_success_";
    "fig5d_rel_stop_error_safe100_";
    "fig5d_rel_stop_error_safe98_";
    "fig5e_best_relerr_by_alpha"];
for ai = 1:numel(alphaValues)
    aTag = formatAlphaTag(alphaValues(ai));
    for pi = 1:numel(legacyPatterns)
        for ext = [".png", ".fig"]
            fpath = fullfile(outDir, legacyPatterns(pi) + aTag + ext);
            if isfile(fpath)
                delete(fpath);
            end
        end
    end
end
end
