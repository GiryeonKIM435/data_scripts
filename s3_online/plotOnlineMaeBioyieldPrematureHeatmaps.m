function outPaths = plotOnlineMaeBioyieldPrematureHeatmaps(designSummary, earlyTbl, pairByType, q1Summary, outDir, cfg)
%plotOnlineMaeBioyieldPrematureHeatmaps Final-update MAE + bioyield / premature
%
% Same color/frames as the mae_r2 heatmap (Final-update MAE, MIN red + BH pink).
% Cell text order: mean±SEM -> bioyield:N -> premature:N.
% bioyield = nSafeStopFail; premature = nEarlyStop (zeros always shown).

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

    failMat = [];
    if ismember("nSafeStopFail", sub.Properties.VariableNames)
        [failMat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "nSafeStopFail", "", mt);
    end
    earlyMat = [];
    if ismember("nEarlyStop", sub.Properties.VariableNames)
        [earlyMat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "nEarlyStop", "", mt);
    end

    annotationLines = cell(size(maeMat));
    annotationLines(:) = {""};
    for yi = 1:size(maeMat, 1)
        for xi = 1:size(maeMat, 2)
            if ~isfinite(maeMat(yi, xi))
                continue;
            end
            parts = strings(0, 1);
            if ~isempty(failMat) && isequal(size(failMat), size(maeMat)) ...
                    && isfinite(failMat(yi, xi))
                parts(end + 1) = sprintf("bioyield: %d", round(failMat(yi, xi))); %#ok<AGROW>
            else
                parts(end + 1) = "bioyield: 0"; %#ok<AGROW>
            end
            if ~isempty(earlyMat) && isequal(size(earlyMat), size(maeMat)) ...
                    && isfinite(earlyMat(yi, xi))
                parts(end + 1) = sprintf("premature: %d", round(earlyMat(yi, xi))); %#ok<AGROW>
            else
                parts(end + 1) = "premature: 0"; %#ok<AGROW>
            end
            annotationLines{yi, xi} = strjoin(parts, newline);
        end
    end

    nondiffMask = [];
    if strlength(string(refInfo.methodKey)) > 0
        nondiffMask = buildKrWilcoxonNondiffMask( ...
            pairSlice, mt, refInfo.methodKey, ...
            struct("alpha", alphaSlice, "referenceVariant", refInfo.variant));
    end

    layout = resolveKrHeatmapLayout(prefix, starts, widths);
    outPath = fullfile(outDir, "fig4_3_online_finalupdate_mae_bioyield_premature_" + prefix + ".png");
    plotKrGridHeatmap(maeMat, semMat, starts, widths, ...
        title=sprintf("Online Final-update MAE + bioyield / premature (%s, \\alpha_{0.95}, %s)", ...
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
