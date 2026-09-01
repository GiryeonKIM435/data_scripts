function outPath = plotOfflineBestScatters(cohort, cfg, methodKeys, panelLabels, outDir)
%plotOfflineBestScatters 結果4.2: best 区間の LOOCV 実測–予測散布図（2 パネル）

if ~isfolder(outDir)
    mkdir(outDir);
end
nPanels = numel(methodKeys);
dpi = 300;
if isfield(cfg, "analysis") && isfield(cfg.analysis, "figureDpi")
    dpi = cfg.analysis.figureDpi;
end

fig = figure("Color", "w", "Position", [80 80 520 * nPanels 480], "Visible", "off");
tiled = tiledlayout(fig, 1, nPanels, "Padding", "compact", "TileSpacing", "compact");

for pi = 1:nPanels
    key = string(methodKeys(pi));
    off = buildOfflineKrLoocvResults(cohort, cfg, struct( ...
        "methodKey", key, "krVariant", cfg.deploy.krVariant));
    cv = off.cvResults;

    ax = nexttile(tiled);
    scatter(ax, cv.yTrue, cv.yPred, 36, "filled");
    hold(ax, "on");
    lims = [min(cv.yTrue), max(cv.yTrue)];
    plot(ax, lims, lims, "k--");
    xlabel(ax, "Observed yield [N]");
    ylabel(ax, "LOOCV predicted yield [N]");
    title(ax, sprintf("%s (%s)", panelLabels(pi), off.methodLabel));
    subtitle(ax, sprintf("MAE=%.2f N (%.1f%%), R^2=%.3f, n=%d", ...
        cv.metrics.mae, off.maePct, cv.metrics.r2, cv.n));
    grid(ax, "on");
end

outPath = fullfile(outDir, "fig4_2_offline_best_scatter.png");
exportPaperFigure(fig, outPath, "Resolution", dpi);
end
