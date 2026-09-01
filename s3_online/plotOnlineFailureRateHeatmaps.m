function outPaths = plotOnlineFailureRateHeatmaps(designSummary, outDir, cfg)
%plotOnlineFailureRateHeatmaps 結果4.3: 安全停止失敗率ヒートマップ
%
% failureRate = 1 - safeStopRate（区間ごと）。

if ~isfolder(outDir)
    mkdir(outDir);
end

outPaths = strings(0, 1);
if ~ismember("failureRate", designSummary.Properties.VariableNames)
    warning("plotOnlineFailureRateHeatmaps:NoColumn", ...
        "failureRate 列がありません。スキップします。");
    return;
end

methodTypes = ["force_abs"; "force_trailing"];
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");

vals = designSummary.failureRate;
vals = vals(isfinite(vals));
clim = [0, 1];
if ~isempty(vals)
    clim = [0, max(1, max(vals))];
end

for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    prefix = prefixByType.(char(mt));
    sub = designSummary(string(designSummary.methodType) == mt, :);
    if isempty(sub)
        continue;
    end
    [frMat, ~, starts, widths, ~] = buildKrGridMatrices( ...
        sub, "failureRate", "", mt);
    if isempty(frMat) || all(isnan(frMat(:)))
        continue;
    end
    layout = resolveKrHeatmapLayout(prefix, starts, widths);
    outPath = fullfile(outDir, "fig4_3_online_failure_rate_" + prefix + ".png");
    plotKrGridHeatmap(frMat, [], starts, widths, ...
        title=sprintf("Safe-stop failure rate (%s, \\alpha_{design})", ...
        strrep(prefix, "_", "\_")), ...
        outPath=outPath, cfg=cfg, clim=clim, ...
        colorbarLabel="Failure rate [-]", ...
        highlightMode="min", scaleMode="abs", showSem=false, ...
        figureSize=layout.figSize, compactText=layout.compactText, ...
        xLabel=layout.xLabel, yLabel=layout.yLabel, valueDecimals=2);
    outPaths(end + 1, 1) = outPath; %#ok<AGROW>
end

end
