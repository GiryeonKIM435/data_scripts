function outPaths = plotOnlineStoppingMarginHeatmaps(designSummary, outDir, cfg)
%plotOnlineStoppingMarginHeatmaps 結果4.3: 停止余裕ヒートマップ
%
% stoppingMargin = (F_yield - F_stop) / F_yield（safe-stop 成功試料の平均）。

if ~isfolder(outDir)
    mkdir(outDir);
end

outPaths = strings(0, 1);
if ~ismember("stoppingMargin_success_mean", designSummary.Properties.VariableNames)
    warning("plotOnlineStoppingMarginHeatmaps:NoColumn", ...
        "stoppingMargin_success_mean 列がありません。スキップします。");
    return;
end

methodTypes = ["force_abs"; "force_trailing"];
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");

vals = designSummary.stoppingMargin_success_mean;
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
    [mMat, semMat, starts, widths, ~] = buildKrGridMatrices( ...
        sub, "stoppingMargin_success_mean", "stoppingMargin_success_sem", mt);
    if isempty(mMat) || all(isnan(mMat(:)))
        continue;
    end
    layout = resolveKrHeatmapLayout(prefix, starts, widths);
    outPath = fullfile(outDir, "fig4_3_online_stopping_margin_" + prefix + ".png");
    plotKrGridHeatmap(mMat, semMat, starts, widths, ...
        title=sprintf("Stopping margin (%s, \\alpha_{design})", ...
        strrep(prefix, "_", "\_")), ...
        outPath=outPath, cfg=cfg, clim=clim, ...
        colorbarLabel="(F_{yield}-F_{stop}) / F_{yield} [%]", ...
        highlightMode="max", scaleMode="pct", showSem=true, ...
        figureSize=layout.figSize, compactText=layout.compactText, ...
        xLabel=layout.xLabel, yLabel=layout.yLabel);
    outPaths(end + 1, 1) = outPath; %#ok<AGROW>
end

end
