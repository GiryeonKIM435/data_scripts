function outPaths = plotOnlineMaeR2Heatmaps(designSummary, pairByType, q1Summary, outDir, cfg)
%plotOnlineMaeR2Heatmaps 結果4.3: Final-update MAE ヒートマップ（R^2 併記）
%
% 色 = Final-update MAE、セル注記 = mean±SEM + R^2 + fail=n。
% MIN 赤枠 + BH 非有意（q>=0.05）ピンク枠。色尺度はオフライン（4.2）と共有。

if ~isfolder(outDir)
    mkdir(outDir);
end

valueField = "finalUpdateMae";
semField = "finalUpdateMae_sem";

maeClim = computeGlobalMaeHeatmapClim(q1Summary, designSummary, cfg);
alphaSlice = cfg.q7.designAlphaSlice;

methodTypes = cfg.q7.methodTypes(:);
if isempty(methodTypes)
    methodTypes = "force_abs";
end
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");

outPaths = strings(0, 1);
for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    prefix = prefixByType.(char(mt));
    sub = designSummary(string(designSummary.methodType) == mt, :);
    if isempty(sub)
        continue;
    end

    pairTable = resolvePairTableForType(pairByType, mt);
    pairSlice = pairTable;
    if ~isempty(pairSlice) && istable(pairSlice) ...
            && ismember("alpha", pairSlice.Properties.VariableNames)
        pairSlice = pairSlice(pairSlice.alpha == alphaSlice, :);
    end
    refInfo = resolveKrHeatmapReference(pairSlice, sub, "finalUpdateMae");

    [maeMat, semMat, starts, widths, ~] = buildKrGridMatrices(sub, valueField, semField, mt);
    if isempty(maeMat) || all(isnan(maeMat(:)))
        continue;
    end
    [r2Mat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "finalUpdateR2", "", mt);
    failMat = [];
    if ismember("nSafeStopFail", sub.Properties.VariableNames)
        [failMat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "nSafeStopFail", "", mt);
    end

    annotationLines = cell(size(maeMat));
    annotationLines(:) = {""};
    if isequal(size(r2Mat), size(maeMat))
        for yi = 1:size(maeMat, 1)
            for xi = 1:size(maeMat, 2)
                parts = strings(0, 1);
                if isfinite(r2Mat(yi, xi))
                    parts(end + 1) = formatHeatmapR2Annotation(r2Mat(yi, xi)); %#ok<AGROW>
                end
                if ~isempty(failMat) && isfinite(failMat(yi, xi)) && failMat(yi, xi) > 0
                    parts(end + 1) = sprintf("fail=%d", round(failMat(yi, xi))); %#ok<AGROW>
                end
                if ~isempty(parts)
                    annotationLines{yi, xi} = strjoin(parts, newline);
                end
            end
        end
    end

    nondiffMask = [];
    if strlength(string(refInfo.methodKey)) > 0
        nondiffMask = buildKrWilcoxonNondiffMask( ...
            pairSlice, mt, refInfo.methodKey, ...
            struct("alpha", alphaSlice, "referenceVariant", refInfo.variant));
    end

    layout = resolveKrHeatmapLayout(prefix, starts, widths);
    outPath = fullfile(outDir, "fig4_3_online_finalupdate_mae_r2_" + prefix + ".png");
    plotKrGridHeatmap(maeMat, semMat, starts, widths, ...
        title=sprintf("Online Final-update MAE (%s, \\alpha_{0.95}, %s)", ...
        strrep(prefix, "_", "\_"), string(cfg.deploy.krVariant)), ...
        outPath=outPath, cfg=cfg, clim=maeClim, colorbarLabel="Final-update MAE [N]", ...
        highlightMode="minNondiffFdr", scaleMode="abs", showSem=true, ...
        figureSize=layout.figSize, compactText=layout.compactText, ...
        xLabel=layout.xLabel, yLabel=layout.yLabel, ...
        nondiffMask=nondiffMask, ...
        annotationLines=annotationLines);
    outPaths(end + 1, 1) = outPath; %#ok<AGROW>
end

end

function pairTable = resolvePairTableForType(pairByType, methodType)
pairTable = [];
if isempty(pairByType)
    return;
end
if istable(pairByType)
    pairTable = pairByType;
    return;
end
if ~isstruct(pairByType)
    return;
end
key = char(methodType);
if isfield(pairByType, key)
    pairTable = pairByType.(key);
elseif methodType == "force_trailing" && isfield(pairByType, "force_trail")
    pairTable = pairByType.force_trail;
end
end
