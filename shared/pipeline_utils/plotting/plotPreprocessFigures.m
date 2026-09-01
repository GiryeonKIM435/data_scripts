function plotPreprocessFigures(cfg, step)
%PLOTPREPROCESSFIGURES 03_preprocess 段階の figure 出力

if ~cfg.figures.enabled, return; end
pu = plotUtils();
figRoot = fullfile(cfg.out.preprocess, "figures", step);
pu.ensureDir(figRoot);

switch step
    case "outliers"
        plotOutliers(cfg, pu, figRoot);
    case "cohort"
        plotCohort(cfg, pu, figRoot);
end
end

function plotOutliers(cfg, pu, figRoot)
if ~isfile(cfg.paths.outlierDiagnostic), return; end
s = load(cfg.paths.outlierDiagnostic, "diagnostic");
d = s.diagnostic;
if ~isfield(d, "outlierLog") || isempty(d.outlierLog), return; end
scores = [d.outlierLog.score];
ids = [d.outlierLog.id];
fig = pu.newOffFigure("outlier MAD scores");
bar(scores); xlabel("removal event"); ylabel("MAD score"); grid on;
pu.saveStageFigure(fig, figRoot, "01_mad_scores", cfg.figures);
fig2 = pu.newOffFigure("removed IDs");
bar(ids); xlabel("index"); ylabel("id"); title(sprintf("removed n=%d", numel(ids)));
pu.saveStageFigure(fig2, figRoot, "02_removed_ids", cfg.figures);
end

function plotCohort(cfg, pu, figRoot)
if ~isfile(cfg.paths.cohortManifest), return; end
s = load(cfg.paths.cohortManifest, "manifest");
m = s.manifest;
fig = pu.newOffFigure("cohort counts");
bar([m.nComplete, m.nKept, m.nRemoved]);
set(gca, "XTickLabel", {"complete", "kept", "removed"}); ylabel("count"); grid on;
pu.saveStageFigure(fig, figRoot, "01_cohort_counts", cfg.figures);

if ~isfile(cfg.paths.masterTable), return; end
sm = load(cfg.paths.masterTable, "masterTable");
tbl = sm.masterTable;
preds = PredictorRegistry().paramPredictors;
preds = preds(ismember(preds, tbl.Properties.VariableNames));
nP = min(6, numel(preds));
fig2 = pu.newOffFigure("predictor vs yield");
t = tiledlayout(fig2, 2, 3, "TileSpacing", "compact");
for i = 1:nP
    ax = nexttile(t);
    scatter(ax, tbl.(preds(i)), tbl.yieldPointN, 20, "filled");
    xlabel(ax, preds(i)); ylabel("yieldPointN"); grid(ax, "on");
end
pu.saveStageFigure(fig2, figRoot, "02_predictor_vs_yield", cfg.figures);
end
