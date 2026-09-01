function results = run_burgers_fit_audit(cfg, opts)
%RUN_BURGERS_FIT_AUDIT Jeffreys model fit rules + two-panel example
%
% Prefer the public entry run_jeffreys_fit_audit.
% Panel (a): protocol hold band; (b): measurement + Jeffreys fit.

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end

fitOpts = burgersDefaultOpts();
if isfield(cfg, "fitBurgers") && ~isempty(cfg.fitBurgers)
    fitOpts = cfg.fitBurgers;
end

outDir = fullfile(cfg.out.root, "sec4_jeffreys_fit");
if ~isfolder(outDir)
    mkdir(outDir);
end
figDir = cfg.out.paperFigures;
tabDir = cfg.out.paperTables;
if ~isfolder(figDir), mkdir(figDir); end
if ~isfolder(tabDir), mkdir(tabDir); end

fitPath = resolveTomatoWithFitPath(cfg);
if ~isfile(fitPath)
    error("run_burgers_fit_audit:NoFit", ...
        "tomato_with_fit.mat missing (run doEstimate for Jeffreys fit): %s", fitPath);
end

s = load(fitPath);
if ~isfield(s, "fitResults")
    error("run_burgers_fit_audit:BadFit", "fitResults missing: %s", fitPath);
end
fitResults = s.fitResults;
if isfield(s, "tomatoDataWithFit")
    tomatoData = s.tomatoDataWithFit;
elseif isfile(cfg.paths.tomatoFiltered)
    sf = load(cfg.paths.tomatoFiltered, "tomatoFiltered");
    tomatoData = sf.tomatoFiltered;
else
    error("run_burgers_fit_audit:NoTomato", ...
        "tomatoDataWithFit / tomato_filtered missing.");
end

n = numel(fitResults);
successMask = false(1, n);
r2Vals = nan(1, n);
hasSeg = false(1, n);
for i = 1:n
    successMask(i) = logical(fitResults(i).success);
    if isfield(fitResults(i), "r2")
        r2Vals(i) = fitResults(i).r2;
    end
    seg = fitResults(i).creepSegment;
    hasSeg(i) = isstruct(seg) && isfield(seg, "tSecRel") && ~isempty(seg.tSecRel) ...
        && isfield(seg, "yhatMm") && ~isempty(seg.yhatMm);
end
failMask = ~successMask;
nSuccess = nnz(successMask);
nFail = nnz(failMask);

%% Rules text
rulesPath = fullfile(outDir, "jeffreys_fit_rules.txt");
fid = fopen(rulesPath, "w", "n", "UTF-8");
fprintf(fid, "Jeffreys creep identification rules\n");
fprintf(fid, "================================================================================\n\n");
fprintf(fid, "0. Protocol segment used for identification\n");
fprintf(fid, "   - Creep hold only (nominal F = %.2f N, hold = %.0f s)\n", ...
    fitOpts.creepLoadGram * 1e-3 * 9.80665, fitOpts.creepHoldDurationSec);
fprintf(fid, "   - Hold window: recovery-start detection then look-back %.0f s;\n", ...
    fitOpts.creepHoldDurationSec);
fprintf(fid, "     creep end refined by speed threshold\n");
fprintf(fid, "   - Relative time t=0 and delta=0 at creep-window start\n\n");
fprintf(fid, "1. Reduced 3-parameter Jeffreys model (no k_M on hold)\n");
fprintf(fid, "   - Parameters: k_K (k2), c_M (c1), c_K (c2)\n");
fprintf(fid, "   - Log-space nonlinear least squares, %d random starts\n", ...
    fitOpts.fitNumStarts);
fprintf(fid, "   - Huber robust loss (delta = %.2f) when enabled\n\n", ...
    fitOpts.fitRobustDelta);
fprintf(fid, "2. Success / rejection\n");
fprintf(fid, "   - Fit failure -> success=false (message from exception)\n");
fprintf(fid, "   - Optional bilateral-IQR reject on log10(k2,c1,c2): multiplier=%.1f\n", ...
    fitOpts.outlierIqrMultiplier);
fprintf(fid, "     (rejectParamOutliers=%d)\n\n", logical(fitOpts.rejectParamOutliers));
fprintf(fid, "3. Audit figure sample selection\n");
fprintf(fid, "   - Panels (a)(b): success with creepSegment + finite R2 closest to median R2\n");
fclose(fid);
copyfile(rulesPath, fullfile(tabDir, "jeffreys_fit_rules.txt"));

%% Representative specimen (success, near-median R2)
candOk = find(successMask & hasSeg & isfinite(r2Vals));
if isempty(candOk)
    error("run_burgers_fit_audit:NoSuccess", "No successful fit (creepSegment+R2).");
end
medR2 = median(r2Vals(candOk), "omitnan");
[~, nearest] = min(abs(r2Vals(candOk) - medR2));
idxOk = candOk(nearest);
idOk = fitResults(idxOk).id;
itemOk = findItemById(tomatoData, idOk);

bandColor = [0.55 0.85 0.95];
curveColor = [0.75 0.2 0.2];
fitColor = [0.15 0.15 0.15];

fig = figure("Color", "w", "Position", [60 60 840 360], "Visible", "off");
tl = tiledlayout(fig, 1, 2, "Padding", "compact", "TileSpacing", "compact");

axA = nexttile(tl);
winOk = resolveCreepHoldWindow(itemOk, fitOpts);
plotProtocolPanel(axA, winOk, bandColor, curveColor);
xlabel(axA, "t (s)");
ylabel(axA, "\delta (mm)", "Interpreter", "tex");
title(axA, sprintf("ID %d: (a) Protocol (hold band)", idOk), ...
    "FontSize", 9, "Interpreter", "none");

axB = nexttile(tl);
seg = fitResults(idxOk).creepSegment;
hMeasB = plot(axB, seg.tSecRel, seg.defMm, ".", "MarkerSize", 4, "Color", curveColor);
hold(axB, "on");
hFit = plot(axB, seg.tSecRel, seg.yhatMm, "-", "Color", fitColor, "LineWidth", 1.4);
grid(axB, "on");
xlabel(axB, "t_{creep} (s)", "Interpreter", "tex");
ylabel(axB, "\delta (mm)", "Interpreter", "tex");
title(axB, sprintf("ID %d: (b) Fit (R^2=%.3f)", idOk, r2Vals(idxOk)), ...
    "FontSize", 9, "Interpreter", "tex");
yMaxB = max(seg.defMm(isfinite(seg.defMm)), [], "omitnan");
if ~(isfinite(yMaxB) && yMaxB > 0)
    yMaxB = 1;
end
ylim(axB, [0, yMaxB * 1.05]);

lgd = legend([hMeasB, hFit], {"Measurement", "Jeffreys fit"}, ...
    "Interpreter", "none", "FontSize", 9, "Orientation", "horizontal");
lgd.Layout.Tile = "north";

figPath = fullfile(outDir, "fig_jeffreys_fit_examples.png");
dpi = 300;
if isfield(cfg, "analysis") && isfield(cfg.analysis, "figureDpi")
    dpi = cfg.analysis.figureDpi;
end
exportPaperFigure(fig, figPath, "Resolution", dpi);
copyfile(figPath, fullfile(figDir, "fig_methods_jeffreys_fit_examples.png"));
figSibling = strrep(figPath, ".png", ".fig");
if isfile(figSibling)
    copyfile(figSibling, fullfile(figDir, "fig_methods_jeffreys_fit_examples.fig"));
end

idxFail = find(failMask, 1, "first");
idFail = nan;
if ~isempty(idxFail)
    idFail = fitResults(idxFail).id;
end
summaryTbl = table(n, nSuccess, nFail, idOk, r2Vals(idxOk), idFail, ...
    'VariableNames', {'nSource', 'nSuccess', 'nFail', 'idOk', 'r2Ok', 'idFail'});
writetable(summaryTbl, fullfile(outDir, "table_jeffreys_fit_counts.csv"));
writetable(summaryTbl, fullfile(tabDir, "table_jeffreys_fit_counts.csv"));

results = struct();
results.createdAt = datetime("now");
results.rulesPath = rulesPath;
results.figPath = figPath;
results.summary = summaryTbl;
results.idOk = idOk;
results.idFail = idFail;
results.r2Ok = r2Vals(idxOk);
fprintf("Jeffreys fit audit: success=%d/%d, example OK=ID %d (R2=%.3f) -> %s\n", ...
    nSuccess, n, idOk, r2Vals(idxOk), outDir);
end

function fitPath = resolveTomatoWithFitPath(cfg)
if isfield(cfg, "paths") && isfield(cfg.paths, "tomatoWithFit") ...
        && strlength(string(cfg.paths.tomatoWithFit)) > 0
    fitPath = char(string(cfg.paths.tomatoWithFit));
    return;
end
fitPath = fullfile(cfg.studyRoot, "outputs", "prepare", "02_estimate", "tomato_with_fit.mat");
end

function item = findItemById(tomatoData, id)
ids = [tomatoData.id];
idx = find(ids == id, 1);
if isempty(idx)
    error("run_burgers_fit_audit:MissingId", "ID %g not found in tomatoData.", id);
end
item = tomatoData(idx);
end

function hMeas = plotProtocolPanel(ax, win, bandColor, curveColor)
t = win.tSec(:);
y = win.defMm(:);
hMeas = plot(ax, t, y, ".", "MarkerSize", 4, "Color", curveColor);
hold(ax, "on");
yl = ylim(ax);
if isfield(win, "creepStartSec") && isfield(win, "creepEndSec") ...
        && isfinite(win.creepStartSec) && isfinite(win.creepEndSec)
    xPatch = [win.creepStartSec, win.creepEndSec, win.creepEndSec, win.creepStartSec];
    yPatch = [yl(1), yl(1), yl(2), yl(2)];
    hp = patch(ax, xPatch, yPatch, bandColor, "EdgeColor", "none", "FaceAlpha", 0.35);
    uistack(hp, "bottom");
    xline(ax, win.creepStartSec, "--", "Color", [0.1 0.45 0.65], "LineWidth", 1.0);
    text(ax, win.creepStartSec, yl(2), " t_{creep}=0", ...
        "VerticalAlignment", "top", "FontSize", 8, "Color", [0.1 0.35 0.55], ...
        "Interpreter", "tex");
end
grid(ax, "on");
ylim(ax, yl);
end
