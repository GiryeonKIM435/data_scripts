function run_correlation_partial(opts)
%RUN_CORRELATION_PARTIAL Pearson/Spearman/偏相関 + 図

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);
u = pipelineUtils();
pu = plotUtils();
cvCfg = cfg.cv;
paths = u.buildAnalyzePaths(cfg, "correlation_partial");
useOutlierFilter = opts.analyze.useOutlierFilter;

if shouldSkipCompute(opts, char(paths.resultMat))
    fprintf("既存: %s\n", paths.resultMat);
    return;
end

cohort = loadCohort(cfg.paths.masterTable, cfg.paths.cohortManifest, ...
    struct("useOutlierFilter", useOutlierFilter));
u.printCohortSummary(cohort);
tbl = cohort.predictorTable;
predictors = cohort.predictorNames;
y = cohort.y;
n = cohort.n;
p = numel(predictors);
X = tbl{:, predictors};
B = cvCfg.bootstrapSamples;
alpha = 0.05;
rng(cvCfg.bootstrapSeed);

[rPearson, pPearson] = corr(X, y, "Type", "Pearson", "Rows", "complete");
[rSpearman, pSpearman] = corr(X, y, "Type", "Spearman", "Rows", "complete");
ciPearson = bootstrapCorr(X, y, "Pearson", B, alpha);
ciSpearman = bootstrapCorr(X, y, "Spearman", B, alpha);

rPartial = nan(p, 1); pPartial = nan(p, 1); ciPartial = nan(p, 2);
for j = 1:p
    others = setdiff(1:p, j);
    [rPartial(j), pPartial(j)] = partialCorrelation(X(:, j), y, X(:, others));
    ciPartial(j, :) = bootstrapPartialCorr(X(:, j), y, X(:, others), B, alpha);
end

augNames = ["yieldPointN", predictors(:).'];
Xy = [y, X];
corrMatPearson = corr(Xy, "Rows", "complete");
corrMatSpearman = corr(Xy, "Type", "Spearman", "Rows", "complete");

corrTable = table(predictors(:), rPearson, pPearson, ciPearson(:,1), ciPearson(:,2), ...
    rSpearman, pSpearman, ciSpearman(:,1), ciSpearman(:,2), ...
    rPartial, pPartial, ciPartial(:,1), ciPartial(:,2), ...
    'VariableNames', {'predictor', 'pearsonR', 'pearsonP', 'pearsonCiLo', 'pearsonCiHi', ...
    'spearmanRho', 'spearmanP', 'spearmanCiLo', 'spearmanCiHi', ...
    'partialR', 'partialP', 'partialCiLo', 'partialCiHi'});
[~, ord] = sort(abs(rPartial), "descend");
corrTable = corrTable(ord, :);

results = struct("createdAt", datetime("now"), "useOutlierFilter", useOutlierFilter, ...
    "cohort", cohort, "corrTable", corrTable, ...
    "pearson", struct("r", rPearson, "p", pPearson, "ci", ciPearson), ...
    "spearman", struct("r", rSpearman, "p", pSpearman, "ci", ciSpearman), ...
    "partial", struct("r", rPartial, "p", pPartial, "ci", ciPartial), ...
    "corrMatrix", struct("names", augNames, "pearson", corrMatPearson, "spearman", corrMatSpearman));

writetable(corrTable, char(paths.datasetCsv));
save(char(paths.resultMat), "results", "corrTable", "-v7");
fprintf("correlation_partial 完了: %s\n", paths.resultMat);

if cfg.figures.enabled
    fig1 = pu.newOffFigure("correlation univariate");
    t1 = tiledlayout(fig1, 1, 2);
    title(t1, pu.formatAnalysisTitle("Univariate correlation ranking", n, useOutlierFilter));
    nexttile(t1); pu.plotCorrRanking(rPearson, ciPearson, predictors, "Pearson r", pPearson);
    nexttile(t1); pu.plotCorrRanking(rSpearman, ciSpearman, predictors, "Spearman rho", pSpearman);
    pu.saveStageFigure(fig1, char(paths.figDir), "01_univariate_correlation_ranking", cfg.figures);

    fig2 = pu.newOffFigure("partial correlation");
    pu.plotCorrRanking(rPartial, ciPartial, predictors, ...
        char(pu.formatAnalysisTitle("partial correlation", n, useOutlierFilter)), pPartial);
    pu.saveStageFigure(fig2, char(paths.figDir), "02_partial_correlation_ranking", cfg.figures);

    fig3 = pu.newOffFigure("correlation heatmaps");
    t3 = tiledlayout(fig3, 1, 2);
    title(t3, pu.formatAnalysisTitle("Correlation heatmaps", n, useOutlierFilter));
    nexttile(t3); pu.plotCorrHeatmap(corrMatPearson, augNames, "Pearson r", augNames);
    nexttile(t3); pu.plotCorrHeatmap(corrMatSpearman, augNames, "Spearman rho", augNames);
    pu.saveStageFigure(fig3, char(paths.figDir), "03_correlation_heatmaps", cfg.figures);

    fig4 = pu.newOffFigure("Pearson vs partial", [80 80 700 550]);
    ptColors = zeros(p, 3);
    for j = 1:p
        ptColors(j, :) = significanceFaceColorLocal(pPartial(j));
    end
    scatter(rPearson, rPartial, 50, ptColors, "filled"); hold on;
    plot([-1 1], [-1 1], "k--"); xline(0); yline(0);
    for j = 1:p
        lbl = sprintf("%s (p=%s%s)", predictors(j), ...
            pu.formatPForDisplay(pPartial(j)), pu.significanceStars(pPartial(j)));
        text(rPearson(j), rPartial(j), "  " + lbl, "FontSize", 7);
    end
    xlabel("Pearson r"); ylabel("partial r");
    title(pu.formatAnalysisTitle("Univariate vs partial (color: partial p)", n, useOutlierFilter));
    axis equal; xlim([-1 1]); ylim([-1 1]); grid on;
    pu.saveStageFigure(fig4, char(paths.figDir), "04_pearson_vs_partial", cfg.figures);
end
end

function rgb = significanceFaceColorLocal(p)
if ~isfinite(p) || p >= 0.05
    rgb = [0.72 0.72 0.72];
elseif p < 0.001
    rgb = [0.85 0.33 0.28];
elseif p < 0.01
    rgb = [0.95 0.55 0.20];
else
    rgb = [0.40 0.60 0.85];
end
end