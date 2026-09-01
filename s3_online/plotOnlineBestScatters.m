function outPath = plotOnlineBestScatters(designPerSample, designSummary, methodKey, panelLabel, outDir, cfg)
%plotOnlineBestScatters 結果4.3: best 条件の Final-update 実測–予測散布図

if ~isfolder(outDir)
    mkdir(outDir);
end
dpi = 300;
if isfield(cfg, "analysis") && isfield(cfg.analysis, "figureDpi")
    dpi = cfg.analysis.figureDpi;
end

fig = figure("Color", "w", "Position", [80 80 520 480], "Visible", "off");
ax = axes(fig);
key = string(methodKey);
if strlength(key) == 0
    axis(ax, "off");
else
    subAll = designPerSample(string(designPerSample.krMethodKey) == key, :);
    sub = subAll(isfinite(subAll.finalUpdateErrorN), :);
    yTrue = sub.yTrue(:);
    yPred = sub.y_hat_finalUpdate(:);
    valid = isfinite(yTrue) & isfinite(yPred);
    yTrue = yTrue(valid);
    yPred = yPred(valid);
    nSuccess = sum(string(subAll.outcome) == "success");
    safeRate = 100 * nSuccess / max(height(subAll), 1);

    alphaVal = nan;
    sumRow = designSummary(string(designSummary.krMethodKey) == key, :);
    if ~isempty(sumRow) && ismember("alphaDesign", sumRow.Properties.VariableNames)
        alphaVal = sumRow.alphaDesign(1);
    end

    if numel(yTrue) < 2
        text(ax, 0.5, 0.5, sprintf("n_{eval}=%d", numel(yTrue)), ...
            "HorizontalAlignment", "center", "Units", "normalized");
        title(ax, sprintf("%s (%s)", panelLabel, key));
        axis(ax, "off");
    else
        m = calcMetrics(yTrue, yPred);
        scatter(ax, yTrue, yPred, 36, "filled");
        hold(ax, "on");
        lims = [min(yTrue), max(yTrue)];
        plot(ax, lims, lims, "k--");
        xlabel(ax, "Observed yield [N]");
        ylabel(ax, "Predicted yield at final update [N]");
        title(ax, sprintf("%s (%s)", panelLabel, key));
        subtitle(ax, sprintf("\\alpha_{0.95}=%.3f, MAE=%.2f N, R^2=%.3f, safe-stop=%.1f%% (n=%d)", ...
            alphaVal, m.mae, m.r2, safeRate, m.n));
        grid(ax, "on");
    end
end

outPath = fullfile(outDir, "fig4_3_online_best_scatter.png");
exportPaperFigure(fig, outPath, "Resolution", dpi);
end
