function outPaths = plotOnlineUtilizationHeatmaps(designSummary, outDir, cfg)
%plotOnlineUtilizationHeatmaps 結果4.3: Force utilized for estimation ヒートマップ
%
% F_used = min(F_stop, F_lastUpdate); 指標 = F_used / F_yield（safe-stop 成功試料の平均）。
% 「推定に実際に利用した力が降伏力の何%に相当するか」を条件別に示す。

if ~isfolder(outDir)
    mkdir(outDir);
end

outPaths = strings(0, 1);
if ~ismember("utilization_success_mean", designSummary.Properties.VariableNames)
    warning("plotOnlineUtilizationHeatmaps:NoColumn", ...
        "utilization_success_mean 列がありません。スキップします。");
    return;
end

methodTypes = ["force_abs"; "force_trailing"];
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");

vals = designSummary.utilization_success_mean;
vals = vals(isfinite(vals));
clim = [];
if ~isempty(vals)
    clim = 100 * [min(vals), max(vals)];
    if clim(1) == clim(2)
        clim = clim + [-1, 1];
    end
end

for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    prefix = prefixByType.(char(mt));
    sub = designSummary(string(designSummary.methodType) == mt, :);
    if isempty(sub)
        continue;
    end
    [utilMat, semMat, starts, widths, ~] = buildKrGridMatrices( ...
        sub, "utilization_success_mean", "utilization_success_sem", mt);
    if isempty(utilMat) || all(isnan(utilMat(:)))
        continue;
    end
    layout = resolveKrHeatmapLayout(prefix, starts, widths);
    outPath = fullfile(outDir, "fig4_3_online_utilization_" + prefix + ".png");
    plotKrGridHeatmap(utilMat, semMat, starts, widths, ...
        title=sprintf("Force utilized for estimation (%s, \\alpha_{design})", ...
        strrep(prefix, "_", "\_")), ...
        outPath=outPath, cfg=cfg, clim=clim, ...
        colorbarLabel="F_{used} / F_{yield} [%]", ...
        highlightMode="min", scaleMode="pct", showSem=true, ...
        figureSize=layout.figSize, compactText=layout.compactText, ...
        xLabel=layout.xLabel, yLabel=layout.yLabel);
    outPaths(end + 1, 1) = outPath; %#ok<AGROW>
end

end
