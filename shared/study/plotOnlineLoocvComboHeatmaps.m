function plotOnlineLoocvComboHeatmaps(summaryTable, alphaValues, outDir, cfg, opts)
%plotOnlineLoocvComboHeatmaps Q3 online LOOCV 統合ヒートマップ（MAE 色 + R² + SSR）

if nargin < 5
    opts = struct();
end
if nargin < 4 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if ~isfield(opts, "figPrefix") || strlength(string(opts.figPrefix)) == 0
    opts.figPrefix = "fig5";
end
if ~isfield(opts, "q1SummaryTable")
    opts.q1SummaryTable = loadQ1SummaryTable(cfg);
end
if ~isfield(opts, "globalMaeClim") || isempty(opts.globalMaeClim) ...
        || numel(opts.globalMaeClim) ~= 2
    opts.globalMaeClim = computeGlobalMaeHeatmapClim(opts.q1SummaryTable, summaryTable, cfg);
end
if ~isfield(opts, "pairTable")
    opts.pairTable = [];
end

requiredCols = ["stopMae_success_bootMean_b5000", "safeStopRate"];
for c = requiredCols
    if ~ismember(c, summaryTable.Properties.VariableNames)
        warning("plotOnlineLoocvComboHeatmaps:MissingCol", ...
            "列 %s がありません。統合ヒートマップをスキップします。", c);
        return;
    end
end
hasR2 = ismember("stopR2_success", summaryTable.Properties.VariableNames);

methodTypes = activeKrMethodTypes(cfg);
prefixByType = struct( ...
    "percent_yield", "yield_pct", ...
    "force_abs", "force_abs", ...
    "force_trailing", "force_trail");

q1BestKey = resolveQ1BestMethodKey(opts.q1SummaryTable, cfg);

for ai = 1:numel(alphaValues)
    alpha = alphaValues(ai);
    aTag = formatComboAlphaTag(alpha);
    for ti = 1:numel(methodTypes)
        mt = methodTypes(ti);
        prefix = prefixByType.(char(mt));
        sub = summaryTable(summaryTable.alpha == alpha ...
            & string(summaryTable.methodType) == mt, :);
        if isempty(sub)
            continue;
        end

        [maeMat, maeSemMat, starts, widths, ~] = buildKrGridMatrices( ...
            sub, "stopMae_success_bootMean_b5000", "stopMae_success_ci_halfwidth_b5000", mt);
        if isempty(maeMat) || all(isnan(maeMat(:)))
            continue;
        end

        if hasR2
            [r2Mat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "stopR2_success", "", mt);
        else
            r2Mat = nan(size(maeMat));
        end
        [ssrMat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "safeStopRate", "", mt);

        annotationLines = buildComboAnnotationLines(r2Mat, ssrMat, maeMat);
        referenceCells = {};
        if strlength(string(q1BestKey)) > 0
            refIdx = findKrGridCellIndex(q1BestKey, mt);
            if ~isempty(refIdx)
                referenceCells = {refIdx};
            end
        end

        layout = resolveKrHeatmapLayout(prefix, starts, widths);
        outPath = fullfile(outDir, ...
            opts.figPrefix + "g_online_loocv_combo_" + prefix + "_" + aTag + ".png");
        pairAlpha = opts.pairTable;
        if ~isempty(pairAlpha) && istable(pairAlpha) && ismember("alpha", pairAlpha.Properties.VariableNames)
            pairAlpha = pairAlpha(pairAlpha.alpha == alpha, :);
        end
        subAlpha = summaryTable(summaryTable.alpha == alpha, :);
        refInfo = resolveKrHeatmapReference(pairAlpha, subAlpha, "stopMae_success");
        nondiffMask = [];
        if strlength(string(refInfo.methodKey)) > 0
            nondiffMask = buildKrWilcoxonNondiffMask(pairAlpha, mt, refInfo.methodKey, ...
                struct("alpha", alpha, "referenceVariant", refInfo.variant));
        end
        plotKrGridHeatmap(maeMat, maeSemMat, starts, widths, ...
            title=sprintf("Online LOOCV combo (MAE color, alpha=%.1f, %s)", alpha, prefix), ...
            outPath=outPath, cfg=cfg, clim=opts.globalMaeClim, ...
            colorbarLabel="Stop MAE [N]", highlightMode="minNondiffFdr", ...
            scaleMode="abs", showSem=true, figureSize=layout.figSize, ...
            compactText=layout.compactText, xLabel=layout.xLabel, yLabel=layout.yLabel, ...
            annotationLines=annotationLines, referenceCells=referenceCells, ...
            referenceLabel="Q1", nondiffMask=nondiffMask);
    end
end

end

function annotationLines = buildComboAnnotationLines(r2Mat, ssrMat, maeMat)
[ny, nx] = size(maeMat);
annotationLines = cell(ny, nx);
for yi = 1:ny
    for xi = 1:nx
        if ~isfinite(maeMat(yi, xi))
            annotationLines{yi, xi} = "";
            continue;
        end
        parts = strings(0, 1);
        if isfinite(r2Mat(yi, xi))
            parts(end + 1, 1) = formatHeatmapR2Annotation(r2Mat(yi, xi)); %#ok<AGROW>
        end
        if isfinite(ssrMat(yi, xi))
            parts(end + 1, 1) = sprintf("SSR=%.0f%%", 100 * ssrMat(yi, xi)); %#ok<AGROW>
        end
        annotationLines{yi, xi} = char(strjoin(parts, newline));
    end
end
end

function aTag = formatComboAlphaTag(alpha)
aTag = "a" + strrep(sprintf("%.1f", alpha), ".", "");
end
