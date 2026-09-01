function u = plotUtils()
%plotUtils 段階別 figure 保存（PNG + FIG）

u = struct( ...
    "ensureDir", @ensureDir, ...
    "stageFigDir", @stageFigDir, ...
    "newOffFigure", @newOffFigure, ...
    "saveStageFigure", @saveStageFigure, ...
    "openPipelineFigure", @openPipelineFigure, ...
    "pagedFigureStem", @pagedFigureStem, ...
    "plotCorrHeatmap", @plotCorrHeatmap, ...
    "plotSelectionFreqHeatmap", @plotSelectionFreqHeatmap, ...
    "plotCorrRanking", @plotCorrRanking, ...
    "plotCoefficientForest", @plotCoefficientForest, ...
    "plotBarHorizontalWithSe", @plotBarHorizontalWithSe, ...
    "plotObsVsPred", @plotObsVsPred, ...
    "plotResiduals", @plotResiduals, ...
    "formatMetricsTitle", @formatMetricsTitle, ...
    "formatSampleCountLabel", @formatSampleCountLabel, ...
    "formatAnalysisTitle", @formatAnalysisTitle, ...
    "plotCvMetricsBars", @plotCvMetricsBars, ...
    "plotCompareMethodsMetrics", @plotCompareMethodsMetrics, ...
    "formatPForDisplay", @formatPForDisplay, ...
    "significanceStars", @significanceStars);

end

function ensureDir(d)
if ~isfolder(d)
    mkdir(d);
end
end

function figDir = stageFigDir(cfg, stageSubdir)
figDir = fullfile(cfg.out.root, stageSubdir, "figures");
ensureDir(figDir);
end

function fig = newOffFigure(name, pos)
if nargin < 2 || isempty(pos)
    pos = [80, 80, 1000, 700];
end
fig = figure("Name", name, "Color", "w", "Position", pos, "Visible", "off");
end

function paths = saveStageFigure(fig, outDir, stem, figCfg)
paths = struct("png", "", "fig", "");
if nargin < 4 || isempty(figCfg)
    figCfg = struct("enabled", true, "savePng", true, "saveFig", true, "resolution", 180);
end
if ~isfield(figCfg, "enabled") || ~figCfg.enabled
    close(fig);
    return;
end
ensureDir(outDir);
base = fullfile(outDir, stem);
% FIG は exportgraphics より先に保存（レンダリング状態の変化を避ける）
if isfield(figCfg, "saveFig") && figCfg.saveFig
    paths.fig = base + ".fig";
    saveFigureCompat(fig, paths.fig, figCfg);
end
if isfield(figCfg, "savePng") && figCfg.savePng
    paths.png = base + ".png";
    exportgraphics(fig, char(paths.png), "BackgroundColor", "white", ...
        "Resolution", getfieldOr(figCfg, "resolution", 180));
end
close(fig);
end

function saveFigureCompat(fig, figPath, figCfg)
% savefig は日本語パスへ直接書くと壊れた FIG になることがある（PNG は exportgraphics で問題なし）
figPath = char(figPath);
if isempty(figPath)
    return;
end
[d, ~, ~] = fileparts(figPath);
if ~isfolder(d)
    mkdir(d);
end
oldVis = fig.Visible;
fig.Visible = "on";
drawnow;
cleanupVis = onCleanup(@() set(fig, "Visible", oldVis)); %#ok<NASGU>
useCompact = true;
if isstruct(figCfg) && isfield(figCfg, "figCompact") && ~figCfg.figCompact
    useCompact = false;
end
tmpFig = fullfile(tempdir, uniqueAsciiTempName("yl_pipe_fig", ".fig"));
saved = false;
if useCompact
    try
        savefig(fig, tmpFig, "compact");
        saved = true;
    catch
    end
end
if ~saved
    try
        savefig(fig, tmpFig);
        saved = true;
    catch
    end
end
if ~saved
    try
        print(fig, tmpFig, "-dfig", "-noui");
        saved = true;
    catch
    end
end
if ~saved
    try
        saveas(fig, tmpFig, "fig");
        saved = true;
    catch me
        warning("plotUtils:SaveFigFailed", "FIG 保存失敗: %s (%s)", figPath, me.message);
        return;
    end
end
if isfile(figPath)
    delete(figPath);
end
[okMove, moveMsg] = movefile(tmpFig, figPath, "f");
if ~okMove
    warning("plotUtils:MoveFigFailed", "FIG の移動に失敗: %s (%s)", figPath, moveMsg);
    if isfile(tmpFig)
        delete(tmpFig);
    end
    return;
end
fi = dir(figPath);
if isempty(fi) || fi.bytes < 100
    warning("plotUtils:FigEmpty", "FIG が空または極小です: %s", figPath);
    return;
end
if isfield(figCfg, "verifyFigRoundtrip") && figCfg.verifyFigRoundtrip
    verifyFigureOpens(figPath);
end
end

function verifyFigureOpens(figPath)
try
    h = openfig(figPath, "invisible", "new");
    close(h);
catch me
    warning("plotUtils:FigVerifyFailed", "FIG 再オープン検証失敗: %s (%s)", figPath, me.message);
end
end

function stem = pagedFigureStem(baseStem, page, nPages)
if nargin < 3 || nPages <= 1
    stem = char(baseStem);
else
    stem = sprintf("%s_p%02d", char(baseStem), page);
end
end

function openPipelineFigure(figPathOrRel)
%openPipelineFigure pipeline 出力 FIG を開く（日本語パス・OneDrive 対策）
if nargin < 1 || isempty(figPathOrRel)
    error("openPipelineFigure:MissingPath", "FIG パスを指定してください。");
end
figPath = char(figPathOrRel);
if ~isfile(figPath)
    yieldPipeline_ensurePaths();
    cfg = PipelineConfig();
    figPath = char(fullfile(cfg.out.root, figPathOrRel));
end
if ~isfile(figPath)
    error("openPipelineFigure:NotFound", "FIG が見つかりません: %s", figPathOrRel);
end
opened = false;
lastErr = "";
% 1) フルパス
try
    openfig(figPath, "visible", "new");
    opened = true;
catch me
    lastErr = me.message;
end
% 2) cd + 相対ファイル名
if ~opened
    figDir = fileparts(figPath);
    [~, figName, figExt] = fileparts(figPath);
    figFile = [figName, figExt];
    origDir = pwd;
    cleanup = onCleanup(@() cd(origDir)); %#ok<NASGU>
    try
        cd(figDir);
        openfig(figFile, "visible", "new");
        opened = true;
    catch me
        lastErr = me.message;
    end
end
% 3) ASCII 一時フォルダへコピーして開く
if ~opened
    tmpFig = fullfile(tempdir, uniqueAsciiTempName("yl_pipe_open", ".fig"));
    copyfile(figPath, tmpFig);
    cleanupTmp = onCleanup(@() deleteFileIfExists(tmpFig)); %#ok<NASGU>
    try
        openfig(tmpFig, "visible", "new");
        opened = true;
    catch me
        lastErr = me.message;
    end
end
if ~opened
    error("openPipelineFigure:OpenFailed", ...
        "FIG を開けませんでした: %s\n%s", figPath, lastErr);
end
fprintf("FIG を開きました: %s\n", figPath);
end

function deleteFileIfExists(p)
if isfile(p)
    delete(p);
end
end

function p = uniqueAsciiTempName(prefix, ext)
if nargin < 2 || isempty(ext)
    ext = "";
end
if ~startsWith(ext, ".")
    ext = "." + ext;
end
p = sprintf("%s_%d_%d%s", prefix, round(posixtime(datetime("now")) * 1e6), randi(1e9), ext);
end

function plotCorrHeatmap(mat, rowLabels, ttl, colLabels, ax)
if nargin < 4 || isempty(colLabels)
    colLabels = rowLabels;
end
if nargin < 5 || isempty(ax)
    ax = gca;
else
    axes(ax);
end
imagesc(ax, mat);
axis(ax, "tight");
axis(ax, "equal");
colormap(ax, turbo);
colorbar(ax);
caxis(ax, [-1, 1] .* max(1, max(abs(mat(:)))));
set(ax, "XTick", 1:numel(colLabels), "XTickLabel", cellstr(colLabels), ...
    "YTick", 1:numel(rowLabels), "YTickLabel", cellstr(rowLabels));
xtickangle(ax, 45);
[nRows, nCols] = size(mat);
for r = 1:nRows
    for c = 1:nCols
        v = mat(r, c);
        if ~isfinite(v), continue; end
        tc = ifelse(abs(v) >= 0.55, [1 1 1], [0 0 0]);
        text(ax, c, r, sprintf("%.2f", v), "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle", "FontSize", 7, "FontWeight", "bold", "Color", tc);
    end
end
title(ax, ttl);
end

function plotSelectionFreqHeatmap(freqMat, rowLabels, colLabels, ttl, ax)
%plotSelectionFreqHeatmap 変数選択頻度 [0,1] のヒートマップ
if nargin < 5 || isempty(ax)
    ax = gca;
else
    axes(ax);
end
rowLabels = string(rowLabels(:));
colLabels = string(colLabels(:));
freqMat = double(freqMat);
imagesc(ax, freqMat);
axis(ax, "tight");
colormap(ax, parula);
cb = colorbar(ax);
cb.Label.String = "selection frequency";
caxis(ax, [0, 1]);
set(ax, "XTick", 1:numel(colLabels), "XTickLabel", cellstr(colLabels), ...
    "YTick", 1:numel(rowLabels), "YTickLabel", cellstr(rowLabels));
xtickangle(ax, 45);
[nRows, nCols] = size(freqMat);
for r = 1:nRows
    for c = 1:nCols
        v = freqMat(r, c);
        if ~isfinite(v), continue; end
        tc = ifelse(v >= 0.55, [1 1 1], [0 0 0]);
        text(ax, c, r, sprintf("%.2f", v), "HorizontalAlignment", "center", ...
            "VerticalAlignment", "middle", "FontSize", 8, "FontWeight", "bold", "Color", tc);
    end
end
title(ax, ttl);
end

function plotCorrRanking(r, ci, names, ttl, pVals, ax)
if nargin < 6 || isempty(ax)
    ax = gca;
else
    axes(ax);
end
[~, ord] = sort(abs(r), "descend");
r = r(ord); ci = ci(ord, :); names = names(ord);
hasP = nargin >= 5 && ~isempty(pVals);
if hasP
    pVals = pVals(ord);
end
nv = numel(r);
yPos = (1:nv).';
errLow = r - ci(:, 1); errHigh = ci(:, 2) - r;
errLow(~isfinite(errLow)) = 0; errHigh(~isfinite(errHigh)) = 0;
barColors = repmat([0.4 0.6 0.85], nv, 1);
if hasP
    for k = 1:nv
        barColors(k, :) = significanceFaceColor(pVals(k));
    end
end
barh(ax, yPos, r, 0.7, "FaceColor", "flat", "CData", barColors);
hold(ax, "on");
errorbar(ax, r, yPos, errLow, errHigh, "horizontal", "k.", "LineWidth", 1, "CapSize", 5);
xline(ax, 0, "Color", [0.4 0.4 0.4]);
set(ax, "YTick", yPos, "YTickLabel", cellstr(names), "YDir", "reverse");
xlabel(ax, ttl); title(ax, ttl + " ranking"); grid(ax, "on");
xLo = min(-1, min(ci(:, 1), [], "omitnan") - 0.05);
xHi = 1.05;
if hasP
    for k = 1:nv
        ann = sprintf("p=%s%s", formatPForDisplay(pVals(k)), significanceStars(pVals(k)));
        text(ax, xHi, yPos(k), ann, "HorizontalAlignment", "left", ...
            "VerticalAlignment", "middle", "FontSize", 7);
    end
    xHi = 1.35;
end
xlim(ax, [xLo, xHi]);
hold(ax, "off");
end

function plotCoefficientForest(coefs, se, pVals, names, xLabel, ttl, ax)
if nargin < 7 || isempty(ax)
    ax = gca;
else
    axes(ax);
end
coefs = coefs(:); se = se(:); pVals = pVals(:); names = string(names(:));
[~, ord] = sort(abs(coefs), "descend");
coefs = coefs(ord); se = se(ord); pVals = pVals(ord); names = names(ord);
nv = numel(coefs);
yPos = (1:nv).';
barColors = zeros(nv, 3);
for k = 1:nv
    barColors(k, :) = significanceFaceColor(pVals(k));
end
barh(ax, yPos, coefs, 0.62, "FaceColor", "flat", "CData", barColors);
hold(ax, "on");
for k = 1:nv
    if isfinite(se(k)) && se(k) > 0
        errorbar(ax, coefs(k), yPos(k), se(k), se(k), "horizontal", "k.", ...
            "LineWidth", 1.2, "CapSize", 6);
    end
end
xline(ax, 0, "Color", [0.4 0.4 0.4]);
set(ax, "YTick", yPos, "YTickLabel", cellstr(names), "YDir", "reverse");
xlabel(ax, xLabel); title(ax, ttl); grid(ax, "on");
lo = coefs - se; hi = coefs + se;
xMin = min([lo; 0], [], "omitnan");
xMax = max([hi; 0], [], "omitnan");
span = max(xMax - xMin, eps);
xAnn = xMax + 0.08 * span;
for k = 1:nv
    ann = sprintf("\\beta=%.3f, SE=%.3f, p=%s%s", ...
        coefs(k), se(k), formatPForDisplay(pVals(k)), significanceStars(pVals(k)));
    text(ax, xAnn, yPos(k), ann, "HorizontalAlignment", "left", ...
        "VerticalAlignment", "middle", "FontSize", 8, "Interpreter", "tex");
end
xlim(ax, [xMin - 0.06 * span, xAnn + 0.55 * span]);
hold(ax, "off");
end

function plotBarHorizontalWithSe(values, se, names, xLabel, ttl, ax)
if nargin < 6 || isempty(ax)
    ax = gca;
else
    axes(ax);
end
values = values(:); se = se(:); names = string(names(:));
[~, ord] = sort(values, "descend");
values = values(ord); se = se(ord); names = names(ord);
nv = numel(values);
yPos = (1:nv).';
barh(ax, yPos, values, 0.62, "FaceColor", [0.45 0.65 0.45]);
hold(ax, "on");
for k = 1:nv
    if isfinite(se(k)) && se(k) > 0
        errorbar(ax, values(k), yPos(k), se(k), se(k), "horizontal", "k.", ...
            "LineWidth", 1.2, "CapSize", 6);
    end
end
set(ax, "YTick", yPos, "YTickLabel", cellstr(names), "YDir", "reverse");
xlabel(ax, xLabel); title(ax, ttl); grid(ax, "on");
hi = values + se;
xMax = max(hi, [], "omitnan");
span = max(xMax, eps);
xAnn = xMax + 0.08 * span;
for k = 1:nv
    ann = sprintf("mean=%.3f, SE=%.3f", values(k), se(k));
    text(ax, xAnn, yPos(k), ann, "HorizontalAlignment", "left", ...
        "VerticalAlignment", "middle", "FontSize", 8);
end
xlim(ax, [0, xAnn + 0.35 * span]);
hold(ax, "off");
end

function s = formatPForDisplay(p)
if ~isfinite(p)
    s = "NA";
elseif p < 0.001
    s = "<0.001";
else
    s = sprintf("%.3f", p);
end
end

function stars = significanceStars(p)
if ~isfinite(p) || p >= 0.05
    stars = "";
elseif p < 0.001
    stars = "***";
elseif p < 0.01
    stars = "**";
else
    stars = "*";
end
end

function rgb = significanceFaceColor(p)
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

function ttl = formatMetricsTitle(scheme, m, nSamples)
if nargin < 2 || isempty(m)
    ttl = string(scheme);
else
    ttl = sprintf("%s: R^2=%.3f, MAE=%.2f, RMSE=%.2f", ...
        scheme, m.r2, m.mae, m.rmse);
end
if nargin >= 3 && ~isempty(nSamples) && isnumeric(nSamples) && isfinite(nSamples)
    ttl = string(ttl) + sprintf(", n=%d", nSamples);
end
end

function lbl = formatSampleCountLabel(n, useOutlierFilter)
% useOutlierFilter kept for call-site compatibility; label shows n only
lbl = sprintf("n=%d", n);
end

function ttl = formatAnalysisTitle(baseTitle, n, useOutlierFilter)
ttl = string(baseTitle) + " (" + string(formatSampleCountLabel(n, useOutlierFilter)) + ")";
end

function plotObsVsPred(ax, yTrue, yPred, schemeOrTitle, metrics, nSamples)
if nargin >= 5 && isstruct(metrics)
    ttl = formatMetricsTitle(schemeOrTitle, metrics, nSamples);
elseif nargin >= 6 && ~isempty(nSamples)
    ttl = string(schemeOrTitle) + sprintf(", n=%d", nSamples);
else
    ttl = schemeOrTitle;
end
axes(ax);
scatter(ax, yTrue, yPred, 36, "filled");
hold(ax, "on");
lims = [min([yTrue; yPred]), max([yTrue; yPred])];
plot(ax, lims, lims, "k--");
hold(ax, "off");
axis(ax, "equal"); xlim(ax, lims); ylim(ax, lims);
grid(ax, "on");
xlabel(ax, "observed"); ylabel(ax, "predicted"); title(ax, ttl);
end

function plotResiduals(ax, yTrue, yPred, schemeOrTitle, metrics, nSamples)
if nargin >= 5 && isstruct(metrics)
    ttl = formatMetricsTitle(string(schemeOrTitle) + " residual", metrics, nSamples);
elseif nargin >= 6 && ~isempty(nSamples)
    ttl = string(schemeOrTitle) + " residual" + sprintf(", n=%d", nSamples);
else
    ttl = string(schemeOrTitle) + " residual";
end
yTrue = yTrue(:);
yPred = yPred(:);
resid = yTrue - yPred;
axes(ax);
scatter(ax, yPred, resid, 36, "filled");
hold(ax, "on");
yline(ax, 0, "k--");
hold(ax, "off");
grid(ax, "on");
xlabel(ax, "predicted");
ylabel(ax, "residual (obs - pred)");
title(ax, ttl);
end

function plotCvMetricsBars(cvRes, layoutTitle, nSamples, useOutlierFilter)
[labels, r2v, maev, rmsev] = cvSchemeVectors(cvRes);
if nargin < 2 || isempty(layoutTitle)
    layoutTitle = "CV metrics";
end
if nargin >= 3 && ~isempty(nSamples)
    layoutTitle = char(formatAnalysisTitle(layoutTitle, nSamples, useOutlierFilter));
end
t = tiledlayout(gcf, 1, 3);
title(t, layoutTitle);
plotMetricBar(nexttile(t), labels, r2v, "R^2");
plotMetricBar(nexttile(t), labels, maev, "MAE");
plotMetricBar(nexttile(t), labels, rmsev, "RMSE");
end

function plotCompareMethodsMetrics(summaryTable, nSamples, useOutlierFilter)
[~, ord] = sort(summaryTable.r2_loocv, "descend");
tbl = summaryTable(ord, :);
if ismember("inputType", tbl.Properties.VariableNames)
    labels = tbl.method + " / " + tbl.inputType;
else
    labels = tbl.method;
end
t = tiledlayout(gcf, 1, 3);
if nargin >= 2 && ~isempty(nSamples)
    title(t, formatAnalysisTitle("Method comparison (LOOCV)", nSamples, useOutlierFilter));
else
    title(t, "Method comparison (LOOCV)");
end
plotMetricBarH(nexttile(t), labels, tbl.r2_loocv, "LOOCV R^2");
plotMetricBarH(nexttile(t), labels, tbl.mae_loocv, "LOOCV MAE");
plotMetricBarH(nexttile(t), labels, tbl.rmse_loocv, "LOOCV RMSE");
end

function [labels, r2v, maev, rmsev] = cvSchemeVectors(cvRes)
labels = ["full", "LOOCV"];
r2v = [cvRes.full.r2, cvRes.loocv.r2];
maev = [cvRes.full.mae, cvRes.loocv.mae];
rmsev = [cvRes.full.rmse, cvRes.loocv.rmse];
if isfield(cvRes, "kfold") && (~isfield(cvRes.kfold, "skipped") || ~cvRes.kfold.skipped)
    labels(end + 1) = string(cvRes.kfold.scheme);
    r2v(end + 1) = cvRes.kfold.r2;
    maev(end + 1) = cvRes.kfold.mae;
    rmsev(end + 1) = cvRes.kfold.rmse;
end
end

function plotMetricBar(ax, labels, values, yLabel)
axes(ax);
values = values(:);
h = bar(ax, categorical(labels), values, 0.65, "FaceColor", [0.35 0.55 0.78]);
ylabel(ax, yLabel); grid(ax, "on");
xPos = h.XEndPoints;
yPad = max(values(isfinite(values)), [], "omitnan");
if isempty(yPad) || yPad == 0
    yPad = 0.02;
else
    yPad = 0.02 * yPad;
end
for k = 1:numel(values)
    if isfinite(values(k))
        text(ax, xPos(k), values(k) + yPad, sprintf("%.3f", values(k)), ...
            "HorizontalAlignment", "center", "VerticalAlignment", "bottom", "FontSize", 8);
    end
end
end

function plotMetricBarH(ax, labels, values, xLabel)
axes(ax);
values = values(:);
h = barh(ax, categorical(labels), values, 0.65, "FaceColor", [0.35 0.55 0.78]);
set(ax, "YDir", "reverse");
xlabel(ax, xLabel); grid(ax, "on");
yPos = h.YEndPoints;
xPad = max(values(isfinite(values)), [], "omitnan");
if isempty(xPad) || xPad == 0
    xPad = 0.02;
else
    xPad = 0.02 * xPad;
end
for k = 1:numel(values)
    if isfinite(values(k))
        text(ax, values(k) + xPad, yPos(k), sprintf("%.3f", values(k)), ...
            "HorizontalAlignment", "left", "VerticalAlignment", "middle", "FontSize", 8);
    end
end
end

function v = getfieldOr(s, f, d)
if isstruct(s) && isfield(s, f), v = s.(f); else, v = d; end
end
function v = ifelse(c,a,b), if c, v=a; else, v=b; end, end
