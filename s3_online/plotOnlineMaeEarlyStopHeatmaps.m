function outPaths = plotOnlineMaeEarlyStopHeatmaps(designSummary, earlyTbl, pairByType, q1Summary, outDir, cfg)
%plotOnlineMaeEarlyStopHeatmaps Final-update MAE ヒートマップ + Δ / early 注記
%
% 色 = Final-update MAE（オフラインと共有 clim）。
% セル順 = mean±SEM → \Delta=+xx.x（online−offline）→ early:N。
% MIN 赤枠 + BH 非有意（q>=0.05）ピンク枠は既存 MAE 図と同型。
% early = 区間上端未到達件数（F_finalUpdate < FL+W-0.5）。

if ~isfolder(outDir)
    mkdir(outDir);
end

valueField = "finalUpdateMae";
semField = "finalUpdateMae_sem";

maeClim = computeGlobalMaeHeatmapClim(q1Summary, designSummary, cfg);
alphaSlice = cfg.q7.designAlphaSlice;

summaryAug = designSummary;
if ~isempty(earlyTbl) && istable(earlyTbl) && height(earlyTbl) > 0 ...
        && ismember("krMethodKey", earlyTbl.Properties.VariableNames) ...
        && ismember("nEarlyStop", earlyTbl.Properties.VariableNames)
    summaryAug = joinEarlyCountsToSummary(summaryAug, earlyTbl);
end
summaryAug = joinOfflineMaeToSummary(summaryAug, q1Summary, cfg);

methodTypes = cfg.q7.methodTypes(:);
if isempty(methodTypes)
    methodTypes = "force_abs";
end
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");

outPaths = strings(0, 1);
for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    prefix = prefixByType.(char(mt));
    sub = summaryAug(string(summaryAug.methodType) == mt, :);
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

    earlyMat = [];
    if ismember("nEarlyStop", sub.Properties.VariableNames)
        [earlyMat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "nEarlyStop", "", mt);
    end
    offlineMaeMat = [];
    if ismember("offlineMaeLoocv", sub.Properties.VariableNames)
        [offlineMaeMat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "offlineMaeLoocv", "", mt);
    end

    annotationLines = cell(size(maeMat));
    annotationLines(:) = {""};
    for yi = 1:size(maeMat, 1)
        for xi = 1:size(maeMat, 2)
            parts = strings(0, 1);
            if ~isempty(offlineMaeMat) && isequal(size(offlineMaeMat), size(maeMat)) ...
                    && isfinite(maeMat(yi, xi)) && isfinite(offlineMaeMat(yi, xi))
                dMae = maeMat(yi, xi) - offlineMaeMat(yi, xi);
                parts(end + 1) = formatHeatmapDeltaMaeAnnotation(dMae); %#ok<AGROW>
            end
            if ~isempty(earlyMat) && isequal(size(earlyMat), size(maeMat)) ...
                    && isfinite(earlyMat(yi, xi))
                parts(end + 1) = sprintf("early: %d", round(earlyMat(yi, xi))); %#ok<AGROW>
            end
            if ~isempty(parts)
                annotationLines{yi, xi} = strjoin(parts, newline);
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
    outPath = fullfile(outDir, "fig4_3_online_finalupdate_mae_early_" + prefix + ".png");
    plotKrGridHeatmap(maeMat, semMat, starts, widths, ...
        title=sprintf("Online Final-update MAE + \\Delta / early (%s, \\alpha_{0.95}, %s)", ...
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

function txt = formatHeatmapDeltaMaeAnnotation(deltaMae)
% TeX interpreter 用。\Delta のみ（単位省略、マス幅対策）。
txt = sprintf('\\Delta = %+0.1f', deltaMae);
end

function summaryAug = joinEarlyCountsToSummary(designSummary, earlyTbl)
summaryAug = designSummary;
if ismember("nEarlyStop", summaryAug.Properties.VariableNames)
    summaryAug.nEarlyStop = [];
end
keys = string(summaryAug.krMethodKey);
nEarly = nan(height(summaryAug), 1);
earlyKeys = string(earlyTbl.krMethodKey);
for i = 1:height(summaryAug)
    hit = find(earlyKeys == keys(i), 1);
    if ~isempty(hit)
        nEarly(i) = double(earlyTbl.nEarlyStop(hit));
    end
end
summaryAug.nEarlyStop = nEarly;
end

function summaryAug = joinOfflineMaeToSummary(designSummary, q1Summary, cfg)
summaryAug = designSummary;
if ismember("offlineMaeLoocv", summaryAug.Properties.VariableNames)
    summaryAug.offlineMaeLoocv = [];
end
offMae = nan(height(summaryAug), 1);
if isempty(q1Summary) || ~istable(q1Summary) || height(q1Summary) == 0 ...
        || ~ismember("krMethodKey", q1Summary.Properties.VariableNames) ...
        || ~ismember("mae_loocv", q1Summary.Properties.VariableNames)
    summaryAug.offlineMaeLoocv = offMae;
    return;
end

q1sub = q1Summary;
krVariant = "";
if isfield(cfg, "deploy") && isfield(cfg.deploy, "krVariant")
    krVariant = string(cfg.deploy.krVariant);
end
if strlength(krVariant) > 0 && ismember("variant", q1sub.Properties.VariableNames)
    q1sub = q1sub(string(q1sub.variant) == krVariant, :);
end

keys = string(summaryAug.krMethodKey);
q1Keys = string(q1sub.krMethodKey);
for i = 1:height(summaryAug)
    hit = find(q1Keys == keys(i), 1);
    if ~isempty(hit)
        offMae(i) = double(q1sub.mae_loocv(hit));
    end
end
summaryAug.offlineMaeLoocv = offMae;
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
