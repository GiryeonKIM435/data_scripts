function plotQ5Figures(diag, offline, online, cfg, outDir, krCol)
%plotQ5Figures Paper-only Q5 figures: post-test LOOCV multi-panel scatter
%
% Extra exploratory plots (online scatter, MAE bars, collinearity, etc.)
% are not generated in the paper reproduction package.

if nargin < 4 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 6
    krCol = ""; %#ok<NASGU>
end

dpi = 300;
if isfield(cfg, "analysis") && isfield(cfg.analysis, "figureDpi")
    dpi = cfg.analysis.figureDpi;
end
paperCfg = resolveQ5PaperTypography(cfg);

% Keep only the paper scatter (fig:res_q5_scatter)
plotQ5OfflineLoocvScatter(offline, cfg, outDir, dpi, paperCfg);
end

function plotQ5CaseDiffStatsFigure(outDir, dpi, paperCfg)
offCsv = fullfile(outDir, "q5_model_comparison_offline.csv");
onCsv = fullfile(outDir, "q5_model_comparison_online.csv");
if ~isfile(offCsv)
    offCsv = fullfile(outDir, "q5_case_diff_offline.csv");
end
if ~isfile(onCsv)
    onCsv = fullfile(outDir, "q5_case_diff_online.csv");
end
if ~isfile(offCsv) && ~isfile(onCsv)
    return;
end

fig = figure("Color", "w", "Position", [80 80 1200 700], "Visible", "off");
tiled = tiledlayout(fig, 2, 1, "Padding", "compact", "TileSpacing", "compact");
title(tiled, "Q5 model comparison vs M0 (bootstrap \DeltaMAE + BH)", ...
    "FontName", paperCfg.fontName, "FontSize", paperCfg.fontSizeTitle);

if isfile(offCsv)
    off = readtable(offCsv);
    ax = nexttile(tiled);
    axis(ax, "off");
    text(ax, 0.01, 0.98, "Offline LOOCV", "FontWeight", "bold", ...
        "FontName", paperCfg.fontName, "VerticalAlignment", "top");
    text(ax, 0.01, 0.90, formatQ5ComparisonTable(off), ...
        "FontName", paperCfg.fontName, "FontSize", paperCfg.fontSizeLegend, ...
        "VerticalAlignment", "top", "Interpreter", "none");
end

if isfile(onCsv)
    on = readtable(onCsv);
    ax = nexttile(tiled);
    axis(ax, "off");
    text(ax, 0.01, 0.98, "Online deploy", "FontWeight", "bold", ...
        "FontName", paperCfg.fontName, "VerticalAlignment", "top");
    text(ax, 0.01, 0.90, formatQ5ComparisonTable(on), ...
        "FontName", paperCfg.fontName, "FontSize", paperCfg.fontSizeLegend, ...
        "VerticalAlignment", "top", "Interpreter", "none");
end

exportPaperFigure(fig, fullfile(outDir, "fig_q5_case_diff_stats.png"), "Resolution", dpi);
end

function txt = formatQ5ComparisonTable(tbl)
if isempty(tbl)
    txt = "No rows";
    return;
end
modelCol = "model";
if ~ismember(modelCol, tbl.Properties.VariableNames)
    modelCol = "caseId";
end
lines = strings(height(tbl) + 1, 1);
lines(1) = "model | deltaMae | CI_lo | CI_hi | pBoot | qBH";
for i = 1:height(tbl)
    ciLo = nan; ciHi = nan; pB = nan; qV = nan;
    if ismember("ciDeltaMaeLo", tbl.Properties.VariableNames)
        ciLo = tbl.ciDeltaMaeLo(i);
        ciHi = tbl.ciDeltaMaeHi(i);
    end
    if ismember("pWilcoxon", tbl.Properties.VariableNames)
        pB = tbl.pWilcoxon(i);
    elseif ismember("pBootstrap", tbl.Properties.VariableNames)
        pB = tbl.pBootstrap(i);
    end
    if ismember("qValueBH", tbl.Properties.VariableNames)
        qV = tbl.qValueBH(i);
    end
    dMae = tbl.deltaMae(i);
    if ismember("deltaMaeMean", tbl.Properties.VariableNames)
        dMae = tbl.deltaMaeMean(i);
    end
    lines(i + 1) = sprintf("%s | %.3f | %.3f | %.3f | %.4f | %.4f", ...
        string(tbl.(modelCol)(i)), dMae, ciLo, ciHi, pB, qV);
end
txt = strjoin(lines, newline);
end

function plotQ5CorrMatrix(diag, cfg, outDir, dpi, paperCfg) %#ok<INUSD>
if ~isfield(diag, "corrMatrixFixed") || isempty(diag.corrMatrixFixed)
    return;
end
C = diag.corrMatrixFixed;
labels = string(diag.corrLabelsFixed);
if isempty(labels)
    labels = string(C.Properties.VariableNames);
end
mat = table2array(C);
n = size(mat, 1);

fig = figure("Color", "w", "Position", [80 80 760 680], "Visible", "off");
ax = axes(fig);
imagesc(ax, 1:n, 1:n, mat, "AlphaData", isfinite(mat));
set(ax, "YDir", "normal");
colormap(ax, redblueMap());
caxis(ax, [-1, 1]);
cb = colorbar(ax);
cb.Label.String = "Pearson r";
xticks(ax, 1:n);
yticks(ax, 1:n);
xticklabels(ax, labels);
yticklabels(ax, labels);
xtickangle(ax, 45);
title(ax, "Correlation matrix", "FontName", paperCfg.fontName);
xlim(ax, [0.5, n + 0.5]);
ylim(ax, [0.5, n + 0.5]);

for yi = 1:n
    for xi = 1:n
        v = mat(yi, xi);
        if ~isfinite(v)
            continue;
        end
        txtColor = "w";
        if abs(v) < 0.55
            txtColor = "k";
        end
        text(ax, xi, yi, sprintf("%.2f", v), ...
            "HorizontalAlignment", "center", "VerticalAlignment", "middle", ...
            "FontSize", paperCfg.fontSizeLegend, "FontName", paperCfg.fontName, ...
            "Color", txtColor);
    end
end

exportPaperFigure(fig, fullfile(outDir, "fig_q5_corr_matrix.png"), "Resolution", dpi);
end

function plotQ5ModelCompare(offline, cfg, outDir, dpi, paperCfg)
if ~isfield(offline, "modelCompareTable") || isempty(offline.modelCompareTable)
    return;
end
cmp = offline.modelCompareTable;
caseOrder = getQ5ModelCaseOrder(cfg);
labels = getQ5ModelCaseLabels(cfg);

rowH = 0.10;
figH = max(620, 120 + numel(caseOrder) * 52);
fig = figure("Color", "w", "Position", [80 80 1100 figH], "Visible", "off");
ax = axes(fig);
axis(ax, "off");
hold(ax, "on");

title(ax, "Multiple regression model comparison (LOOCV)", ...
    "FontName", paperCfg.fontName, "FontSize", paperCfg.fontSizeTitle);

xCols = [0.02, 0.18, 0.30, 0.40, 0.90];
yTop = 0.96;
headers = ["Case", "Predictors", "R^2 (LOOCV)", "MAE (LOOCV)", "Std. coefficients"];
for hi = 1:numel(headers)
    text(ax, xCols(hi), yTop, headers(hi), "FontWeight", "bold", ...
        "FontName", paperCfg.fontName, "FontSize", paperCfg.fontSizeBase, ...
        "VerticalAlignment", "top");
end

rowPtr = 0;
for ci = 1:numel(caseOrder)
    cid = caseOrder(ci);
    sub = cmp(string(cmp.caseId) == cid, :);
    if isempty(sub)
        continue;
    end
    rowPtr = rowPtr + 1;
    y = yTop - rowPtr * rowH;
    text(ax, xCols(1), y, labels(ci), "FontName", paperCfg.fontName, ...
        "FontSize", paperCfg.fontSizeBase, "VerticalAlignment", "top");
    text(ax, xCols(2), y, char(sub.predictors(1)), "FontName", paperCfg.fontName, ...
        "FontSize", paperCfg.fontSizeLegend, "VerticalAlignment", "top", ...
        "Interpreter", "none");
    text(ax, xCols(3), y, sprintf("%.3f", sub.r2_loocv(1)), "FontName", paperCfg.fontName, ...
        "FontSize", paperCfg.fontSizeBase, "VerticalAlignment", "top");
    text(ax, xCols(4), y, sprintf("%.2f N", sub.mae_loocv(1)), "FontName", paperCfg.fontName, ...
        "FontSize", paperCfg.fontSizeBase, "VerticalAlignment", "top");
    text(ax, xCols(5), y, char(sub.beta_std_summary(1)), "FontName", paperCfg.fontName, ...
        "FontSize", paperCfg.fontSizeLegend, "VerticalAlignment", "top", ...
        "Interpreter", "none");
end

exportPaperFigure(fig, fullfile(outDir, "fig_q5_model_compare.png"), "Resolution", dpi);
end

function plotQ5OfflineMaeBar(offline, cfg, outDir, dpi, paperCfg)
if ~isfield(offline, "summaryTable") || isempty(offline.summaryTable)
    return;
end
caseOrder = getQ5ModelCaseOrder(cfg);
labels = getQ5ModelCaseLabels(cfg);
maeVals = nan(numel(caseOrder), 1);
for ci = 1:numel(caseOrder)
    sub = offline.summaryTable(string(offline.summaryTable.caseId) == caseOrder(ci), :);
    if ~isempty(sub)
        maeVals(ci) = sub.mae_loocv(1);
    end
end

fig = figure("Color", "w", "Position", [80 80 1000 480], "Visible", "off");
bar(maeVals);
set(gca, "XTick", 1:numel(caseOrder), "XTickLabel", cellstr(labels), "XTickLabelRotation", 45);
ylabel("LOOCV MAE [N]");
title("Offline LOOCV MAE by model", "FontName", paperCfg.fontName);
grid on;
exportPaperFigure(fig, fullfile(outDir, "fig_q5_offline_mae_compare.png"), "Resolution", dpi);
end

function plotQ5OnlineMaeBar(online, cfg, outDir, dpi, paperCfg)
if ~isfield(online, "summaryTable") || isempty(online.summaryTable)
    return;
end
alpha = cfg.deploy.primaryAlpha;
if isfield(cfg, "q5") && isfield(cfg.q5, "primaryAlpha")
    alpha = cfg.q5.primaryAlpha;
end
perSampleAlpha = isfield(cfg, "q5") && isfield(cfg.q5, "perSampleDesignAlpha") ...
    && logical(cfg.q5.perSampleDesignAlpha);
if perSampleAlpha
    subAll = online.summaryTable;
    titleStr = "Online deploy Final-update MAE by model (\alpha_{design}^{(-i)})";
else
    subAll = online.summaryTable(abs(online.summaryTable.alpha - alpha) < 1e-9, :);
    titleStr = sprintf("Online deploy Final-update MAE by model (\\alpha=%.1f)", alpha);
end
caseOrder = getQ5ModelCaseOrder(cfg);
labels = getQ5ModelCaseLabels(cfg);
maeVals = nan(numel(caseOrder), 1);
for ci = 1:numel(caseOrder)
    sub = subAll(string(subAll.caseId) == caseOrder(ci), :);
    if ~isempty(sub)
        maeVals(ci) = sub.finalUpdateMae(1);
    end
end

fig = figure("Color", "w", "Position", [80 80 1000 480], "Visible", "off");
bar(maeVals);
set(gca, "XTick", 1:numel(caseOrder), "XTickLabel", cellstr(labels), "XTickLabelRotation", 45);
ylabel("Final-update MAE [N]");
title(titleStr, "FontName", paperCfg.fontName);
grid on;
exportPaperFigure(fig, fullfile(outDir, "fig_q5_online_stop_mae_compare.png"), "Resolution", dpi);
end

function plotQ5CollinearityReduction(diag, krCol, cfg, outDir, dpi, paperCfg)
if ~isfield(diag, "caseReduced") || isempty(diag.caseReduced)
    return;
end

caseOrder = getQ5ModelCaseOrder(cfg);
caseLabels = getQ5ModelCaseLabels(cfg);
varOrder = q5DisplayVarOrder(krCol);
nCases = numel(caseOrder);
nVars = numel(varOrder);

stateMat = nan(nCases, nVars);
for ci = 1:nCases
    cid = caseOrder(ci);
    cr = findCaseReduced(diag.caseReduced, cid);
    if isempty(cr)
        continue;
    end
    cands = string(cr.candidates(:));
    for vi = 1:nVars
        tblVar = q5LabelToTableVar(varOrder(vi), krCol);
        if ~ismember(tblVar, cands)
            stateMat(ci, vi) = 0;
        else
            stateMat(ci, vi) = 2;
        end
    end
end

fig = figure("Color", "w", "Position", [80 80 980 520], "Visible", "off");
ax = axes(fig);
imagesc(ax, 1:nVars, 1:nCases, stateMat);
set(ax, "YDir", "normal");
colormap(ax, [0.85 0.85 0.85; 0.55 0.80 0.55]);
caxis(ax, [0, 2]);
xticks(ax, 1:nVars);
yticks(ax, 1:nCases);
xticklabels(ax, varOrder);
yticklabels(ax, caseLabels);
xtickangle(ax, 45);
title(ax, "Predictor inclusion by model (M_{ALL}: fold-inner VIF)", ...
    "FontName", paperCfg.fontName);
xlabel(ax, "Variable");
ylabel(ax, "Model");

exportPaperFigure(fig, fullfile(outDir, "fig_q5_collinearity_reduction.png"), "Resolution", dpi);
end

function plotQ5OfflineLoocvScatter(offline, cfg, outDir, dpi, paperCfg)
% Material for fig:res_q5_scatter (post-test LOOCV multi-panel)
if ~isfield(offline, "scatterData") || isempty(offline.scatterData)
    return;
end
caseOrder = getQ5ModelCaseOrder(cfg);
nCases = numel(caseOrder);
nCols = 4;
nRows = ceil(nCases / nCols);

fig = figure("Color", "w", "Position", [80 80 1200 max(780, 260 * nRows)], "Visible", "off");
tiled = tiledlayout(fig, nRows, nCols, "Padding", "compact", "TileSpacing", "compact");

for ci = 1:numel(caseOrder)
    ax = nexttile(tiled);
    sd = findScatterCase(offline.scatterData, caseOrder(ci));
    if isempty(sd)
        axis(ax, "off");
        continue;
    end
    yTrue = sd.yTrue(:);
    yPred = sd.yPred(:);
    valid = isfinite(yTrue) & isfinite(yPred);
    yTrue = yTrue(valid);
    yPred = yPred(valid);
    m = calcMetrics(yTrue, yPred);
    scatter(ax, yTrue, yPred, 28, "filled"); hold(ax, "on");
    if numel(yTrue) >= 2
        lims = [min(yTrue), max(yTrue)];
        plot(ax, lims, lims, "k--");
    end
    xlabel(ax, "Observed (N)");
    ylabel(ax, "Predicted (N)");
    title(ax, string(caseOrder(ci)), "FontName", paperCfg.fontName, "Interpreter", "none");
    subtitle(ax, sprintf("R^2=%.3f, MAE=%.2f N, n=%d", m.r2, m.mae, m.n));
    grid(ax, "on");
end

exportPaperFigure(fig, fullfile(outDir, "fig_q5_offline_loocv_scatter.png"), "Resolution", dpi);
end

function plotQ5OnlineLoocvScatter(online, cfg, outDir, dpi, paperCfg)
if ~isfield(online, "perSampleTable") || isempty(online.perSampleTable)
    return;
end
alpha = cfg.deploy.primaryAlpha;
if isfield(cfg, "q5") && isfield(cfg.q5, "primaryAlpha")
    alpha = cfg.q5.primaryAlpha;
end
perSampleAlpha = isfield(cfg, "q5") && isfield(cfg.q5, "perSampleDesignAlpha") ...
    && logical(cfg.q5.perSampleDesignAlpha);

per = online.perSampleTable;
caseOrder = getQ5ModelCaseOrder(cfg);
labels = getQ5ModelCaseLabels(cfg);
nCases = numel(caseOrder);
nCols = 4;
nRows = ceil(nCases / nCols);

fig = figure("Color", "w", "Position", [80 80 1200 max(780, 260 * nRows)], "Visible", "off");
tiled = tiledlayout(fig, nRows, nCols, "Padding", "compact", "TileSpacing", "compact");
if perSampleAlpha
    title(tiled, "Online deploy (\alpha_{design}^{(-i)}, Final-update)", ...
        "FontName", paperCfg.fontName);
else
    title(tiled, sprintf("Online deploy (\\alpha=%.1f, Final-update)", alpha), ...
        "FontName", paperCfg.fontName);
end

for ci = 1:numel(caseOrder)
    ax = nexttile(tiled);
    cid = caseOrder(ci);
    if perSampleAlpha
        subAll = per(string(per.caseId) == cid, :);
    else
        subAll = per(string(per.caseId) == cid & abs(per.alpha - alpha) < 1e-9, :);
    end
    nCohort = height(subAll);
    nSuccess = sum(string(subAll.outcome) == "success");
    safeRate = 100 * nSuccess / max(nCohort, 1);

    sub = subAll(isfinite(subAll.finalUpdateErrorN), :);
    yTrue = sub.yTrue(:);
    yPred = sub.y_hat_finalUpdate(:);
    valid = isfinite(yTrue) & isfinite(yPred);
    yTrue = yTrue(valid);
    yPred = yPred(valid);

    if numel(yTrue) < 2
        text(ax, 0.5, 0.5, sprintf("n_{eval}=%d", numel(yTrue)), ...
            "HorizontalAlignment", "center", "Units", "normalized");
        title(ax, labels(ci));
        subtitle(ax, sprintf("Safe-stop rate=%.1f%% (%d/%d)", safeRate, nSuccess, nCohort));
        axis(ax, "off");
        continue;
    end

    m = calcMetrics(yTrue, yPred);
    scatter(ax, yTrue, yPred, 36, "filled"); hold(ax, "on");
    lims = [min(yTrue), max(yTrue)];
    plot(ax, lims, lims, "k--");
    xlabel(ax, "Observed [N]");
    ylabel(ax, "Predicted at final update [N]");
    title(ax, labels(ci), "FontName", paperCfg.fontName);
    subtitle(ax, sprintf("R^2=%.3f, MAE=%.2f N, safe-stop=%.1f%% (%d/%d)", ...
        m.r2, m.mae, safeRate, nSuccess, nCohort));
    grid(ax, "on");
end

exportPaperFigure(fig, fullfile(outDir, "fig_q5_online_loocv_scatter.png"), "Resolution", dpi);
end

function vars = q5DisplayVarOrder(krCol)
vars = ["kr", "k2", "c1", "c2", "weight", "d_eq"];
end

function tblVar = q5LabelToTableVar(label, krCol)
label = string(label);
if label == "kr"
    tblVar = string(krCol);
else
    tblVar = label;
end
end

function cr = findCaseReduced(caseReduced, caseId)
cr = [];
for ri = 1:numel(caseReduced)
    if string(caseReduced(ri).caseId) == string(caseId)
        cr = caseReduced(ri);
        return;
    end
end
end

function sd = findScatterCase(scatterData, caseId)
sd = [];
for i = 1:numel(scatterData)
    if string(scatterData(i).caseId) == string(caseId)
        sd = scatterData(i);
        return;
    end
end
end

function paperCfg = resolveQ5PaperTypography(cfg)
paperCfg = struct("fontName", "Times New Roman", "fontSizeBase", 10.5, ...
    "fontSizeLegend", 8, "fontSizeTitle", 11);
if isfield(cfg, "paper")
    if isfield(cfg.paper, "fontName")
        paperCfg.fontName = cfg.paper.fontName;
    end
    if isfield(cfg.paper, "fontSizeBase")
        paperCfg.fontSizeBase = cfg.paper.fontSizeBase;
    end
    if isfield(cfg.paper, "fontSizeLegend")
        paperCfg.fontSizeLegend = cfg.paper.fontSizeLegend;
    end
    if isfield(cfg.paper, "fontSizeTitle")
        paperCfg.fontSizeTitle = cfg.paper.fontSizeTitle;
    end
end
end

function cmap = redblueMap()
n = 256;
half = floor(n / 2);
r1 = linspace(0.2, 1, half)';
g1 = linspace(0.2, 1, half)';
b1 = ones(half, 1);
r2 = ones(n - half, 1);
g2 = linspace(1, 0.2, n - half)';
b2 = linspace(1, 0.2, n - half)';
cmap = [r1, g1, b1; r2, g2, b2];
end
