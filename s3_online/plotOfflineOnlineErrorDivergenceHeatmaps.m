function [outPaths, summaryTable] = plotOfflineOnlineErrorDivergenceHeatmaps( ...
    benchmark, designPerSample, designSummary, outDir, cfg)
%plotOfflineOnlineErrorDivergenceHeatmaps 結果4.3: オフライン–オンライン誤差乖離
%
% 各条件について mean_i |e_i^on - e_i^off| [N] をヒートマップ表示する。
% 0 に近いほどオフライン LOOCV 性能がオンライン停止時にも維持される。

if nargin < 5 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if ~isfolder(outDir)
    mkdir(outDir);
end

outPaths = strings(0, 1);
summaryTable = table();

if isempty(benchmark) || isempty(designPerSample)
    warning("plotOfflineOnlineErrorDivergenceHeatmaps:NoData", ...
        "Q1/Q7 データ不足のためスキップします。");
    return;
end

methodTypes = cfg.q7.methodTypes(:);
if isempty(methodTypes)
    methodTypes = "force_abs";
end
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");
krVariant = string(cfg.deploy.krVariant);

allKeys = strings(0, 1);
for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    sub = designSummary(string(designSummary.methodType) == mt, :);
    allKeys = [allKeys; string(sub.krMethodKey)]; %#ok<AGROW>
end
allKeys = unique(allKeys, "stable");

[divSummary, detailTable] = computeOfflineOnlineErrorDivergence( ...
    benchmark, designPerSample, allKeys, krVariant);
if isempty(divSummary)
    warning("plotOfflineOnlineErrorDivergenceHeatmaps:Empty", ...
        "誤差乖離を計算できませんでした。");
    return;
end

writetable(divSummary, fullfile(outDir, "offline_online_error_divergence_force_abs.csv"));
if ~isempty(detailTable)
    writetable(detailTable, fullfile(outDir, "offline_online_error_divergence_detail.csv"));
end
summaryTable = divSummary;

clim = [];
vals = divSummary.errorDivergence_mean(isfinite(divSummary.errorDivergence_mean));
if ~isempty(vals)
    clim = [0, max(vals)];
    if clim(2) <= 0
        clim(2) = 1;
    end
end

for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    prefix = prefixByType.(char(mt));
    sub = designSummary(string(designSummary.methodType) == mt, :);
    if isempty(sub)
        continue;
    end
    sub = outerjoin(sub, divSummary, "Keys", "krMethodKey", "MergeKeys", true);
    if ~ismember("errorDivergence_mean", sub.Properties.VariableNames)
        continue;
    end

    [divMat, semMat, starts, widths, ~] = buildKrGridMatrices( ...
        sub, "errorDivergence_mean", "errorDivergence_sem", mt);
    if isempty(divMat) || all(isnan(divMat(:)))
        continue;
    end

    layout = resolveKrHeatmapLayout(prefix, starts, widths);
    outPath = fullfile(outDir, "fig4_3_online_offline_error_divergence_" + prefix + ".png");
    plotKrGridHeatmap(divMat, semMat, starts, widths, ...
        title=sprintf("Offline--online error divergence (%s, \\alpha_{0.95})", ...
        strrep(prefix, "_", "\_")), ...
        outPath=outPath, cfg=cfg, clim=clim, ...
        colorbarLabel="Mean |e^{on}-e^{off}| [N]", ...
        highlightMode="min", scaleMode="abs", showSem=true, ...
        figureSize=layout.figSize, compactText=layout.compactText, ...
        xLabel=layout.xLabel, yLabel=layout.yLabel);
    outPaths(end + 1, 1) = outPath; %#ok<AGROW>
end

end
