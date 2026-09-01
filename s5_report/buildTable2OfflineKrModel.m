function bundle = buildTable2OfflineKrModel(cohort, cfg, outDir)
%buildTable2OfflineKrModel offline kr 近似モデル結果表 + fig2a/b

offline = buildOfflineKrLoocvResults(cohort, cfg);
cv = offline.cvResults;
m = cv.metrics;
nDec = cfg.paper.tableDecimals;

summaryTable = table( ...
    string(offline.methodLabel), ...
    formatPaperDecimal(offline.n, 0), ...
    formatPaperDecimal(offline.meanKr, nDec), ...
    formatPaperDecimal(offline.meanCalibA, nDec), ...
    formatPaperDecimal(offline.meanCalibB, nDec), ...
    formatPaperDecimal(m.mae, nDec), ...
    formatPaperDecimal(offline.maePct, nDec), ...
    formatPaperDecimal(offline.maeSem, nDec), ...
    formatPaperDecimal(m.rmse, nDec), ...
    formatPaperDecimal(m.r2, nDec));
summaryTable.Properties.VariableNames = [ ...
    "KR band", "n", "kr [N/mm]", "a", "b [N]", ...
    "MAE [N]", "MAE [%]", "MAE SEM [N]", "RMSE [N]", "R^2"];

basePath = fullfile(outDir, "table2_offline_kr_model");
bundle = exportPaperTableBundle(summaryTable, basePath, ...
    "Offline kr linear model (LOOCV)", cfg);
bundle.table = summaryTable;
bundle.offline = offline;

figPaths = plotOfflineKrModelFigures(offline, cfg, cfg.out.paperFigures);
bundle.figPaths = figPaths;

end

function paths = plotOfflineKrModelFigures(offline, cfg, figDir)
paths = strings(2, 1);
if ~isfolder(figDir)
    mkdir(figDir);
end

kr = offline.krBatch(:);
y = offline.y(:);
valid = isfinite(kr) & isfinite(y);
cv = offline.cvResults;
nDec = cfg.paper.tableDecimals;

paths(1) = fullfile(figDir, "fig2a_offline_kr_vs_yield.png");
fig = figure("Color", "w", "Position", [80 80 520 480], "Visible", "off");
scatter(kr(valid), y(valid), 36, "filled"); hold on;
if nnz(valid) >= 2
    p = polyfit(kr(valid), y(valid), 1);
    xLine = linspace(min(kr(valid)), max(kr(valid)), 100);
    plot(xLine, polyval(p, xLine), "r-", "LineWidth", 1.2);
end
xlabel("Offline kr [N/mm]");
ylabel("Observed yield [N]");
title(sprintf("Offline: kr vs yield (%s)", offline.methodLabel));
subtitle("Exploratory OLS on full sample");
grid on;
exportPaperFigure(fig, paths(1), "Resolution", cfg.analysis.figureDpi);

paths(2) = fullfile(figDir, "fig2b_offline_loocv_scatter.png");
fig = figure("Color", "w", "Position", [80 80 520 480], "Visible", "off");
scatter(cv.yTrue, cv.yPred, 36, "filled"); hold on;
lims = [min(cv.yTrue), max(cv.yTrue)];
plot(lims, lims, "k--");
xlabel("Observed yield [N]");
ylabel("LOOCV predicted yield [N]");
title(sprintf("Offline LOOCV (%s)", offline.methodLabel));
subtitle(sprintf("MAE=%s N (%s%%), RMSE=%s N, R^2=%s, n=%d", ...
    formatPaperDecimal(cv.metrics.mae, nDec), ...
    formatPaperDecimal(offline.maePct, nDec), ...
    formatPaperDecimal(cv.metrics.rmse, nDec), ...
    formatPaperDecimal(cv.metrics.r2, nDec), ...
    cv.n));
grid on;
exportPaperFigure(fig, paths(2), "Resolution", cfg.analysis.figureDpi);
end
