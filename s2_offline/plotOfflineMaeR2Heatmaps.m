function outPaths = plotOfflineMaeR2Heatmaps(summaryTable, pairByType, outDir, cfg, maeClim)
%plotOfflineMaeR2Heatmaps 結果4.2: LOOCV MAE ヒートマップ（R^2 併記）
%
% 色 = LOOCV MAE、セル注記 = mean±SEM + R^2。
% MIN 赤枠 + BH 非有意（q>=0.05）ピンク枠。
% pairByType: methodType ごとのペア表 struct（force_abs / force_trailing）
%   または旧形式の単一 table（後方互換）。
% maeClim を渡せば色尺度を強制できる。

if nargin < 5
    maeClim = [];
end

if ~isfolder(outDir)
    mkdir(outDir);
end

methodTypes = "force_abs";
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");
if isempty(maeClim) || numel(maeClim) ~= 2 || ~all(isfinite(maeClim))
    maeClim = computeGlobalMaeHeatmapClim(summaryTable, [], cfg);
end

outPaths = strings(0, 1);
for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    prefix = prefixByType.(char(mt));
    sub = summaryTable(string(summaryTable.methodType) == mt, :);
    if isempty(sub)
        continue;
    end

    pairTable = resolvePairTableForType(pairByType, mt);
    refInfo = resolveKrHeatmapReference(pairTable, sub, "mae_loocv");

    [maeMat, semMat, starts, widths, ~] = buildKrGridMatrices( ...
        sub, "mae_loocv", "mae_loocv_sem", mt);
    if isempty(maeMat) || all(isnan(maeMat(:)))
        continue;
    end
    [r2Mat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "r2_loocv", "", mt);
    annotationLines = buildR2AnnotationLines(r2Mat, size(maeMat));

    nondiffMask = [];
    if strlength(string(refInfo.methodKey)) > 0
        nondiffMask = buildKrWilcoxonNondiffMask( ...
            pairTable, mt, refInfo.methodKey, ...
            struct("referenceVariant", refInfo.variant));
    end

    layout = resolveKrHeatmapLayout(prefix, starts, widths);
    outPath = fullfile(outDir, "fig4_2_offline_mae_r2_" + prefix + ".png");
    plotKrGridHeatmap(maeMat, semMat, starts, widths, ...
        title=sprintf("Offline LOOCV MAE (%s, %s)", ...
        strrep(prefix, "_", "\_"), string(cfg.deploy.krVariant)), ...
        outPath=outPath, cfg=cfg, clim=maeClim, colorbarLabel="LOOCV MAE [N]", ...
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

function annotationLines = buildR2AnnotationLines(r2Mat, matSize)
annotationLines = cell(matSize);
annotationLines(:) = {""};
if isempty(r2Mat) || ~isequal(size(r2Mat), matSize)
    return;
end
for yi = 1:matSize(1)
    for xi = 1:matSize(2)
        if isfinite(r2Mat(yi, xi))
            annotationLines{yi, xi} = formatHeatmapR2Annotation(r2Mat(yi, xi));
        end
    end
end
end
