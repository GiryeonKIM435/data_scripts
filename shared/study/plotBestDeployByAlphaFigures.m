function outPath = plotBestDeployByAlphaFigures(bestTable, outDir, cfg, opts)
%plotBestDeployByAlphaFigures α × 方式種別の stop-error ベストリーダーボード

if nargin < 4 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "figPrefix") || strlength(string(opts.figPrefix)) == 0
    opts.figPrefix = "fig5e";
end
if ~isfield(opts, "alphaValues") || isempty(opts.alphaValues)
    opts.alphaValues = cfg.deploy.alphaValues(:);
end

outPath = fullfile(outDir, opts.figPrefix + "_best_stoperr_by_alpha.png");
legacyPath = fullfile(outDir, opts.figPrefix + "_best_relerr_by_alpha.png");
for ext = [".png", ".fig"]
    fpath = legacyPath + ext;
    if isfile(fpath)
        delete(fpath);
    end
end
if ~istable(bestTable) || height(bestTable) == 0
    return;
end

alphaValues = opts.alphaValues(:);
allScopes = {'overall', 'yield_pct', 'force_abs', 'force_trail'};
presentScopes = allScopes;
if ismember("scope", bestTable.Properties.VariableNames)
    presentInTable = unique(string(bestTable.scope));
    presentScopes = allScopes(ismember(allScopes, presentInTable));
    if isempty(presentScopes)
        presentScopes = cellstr(presentInTable);
    end
end
if nargin >= 3 && ~isempty(cfg)
    activeTypes = activeKrMethodTypes(cfg);
    if ~ismember("percent_yield", activeTypes)
        presentScopes = presentScopes(~strcmp(presentScopes, "yield_pct"));
    end
end
scopes = presentScopes;
scopeLabels = struct( ...
    'overall', 'Overall', ...
    'yield_pct', 'yield_pct', ...
    'force_abs', 'force_abs', ...
    'force_trail', 'force_trail');

paperCfg = resolvePaperTypography(cfg);
nDec = cfg.paper.tableDecimals;

fig = figure("Color", "w", "Position", [60 60 1280 820], "Visible", "off");
tl = tiledlayout(fig, numel(scopes), numel(alphaValues), "TileSpacing", "compact", "Padding", "compact");

for si = 1:numel(scopes)
    scopeId = scopes{si};
    for ai = 1:numel(alphaValues)
        alpha = alphaValues(ai);
        ax = nexttile(tl);
        axis(ax, "off");
        row = bestTable(abs(bestTable.alpha - alpha) < 1e-9 ...
            & string(bestTable.scope) == string(scopeId), :);
        if isempty(row)
            body = "No feasible method";
        else
            body = formatBestDeployCell(row(1, :), nDec);
        end
        title(ax, sprintf("%s | alpha=%.1f", scopeLabels.(char(scopeId)), alpha), ...
            "FontName", paperCfg.fontName, "FontSize", paperCfg.fontSizeSubtitle, ...
            "FontWeight", "normal");
        text(ax, 0.02, 0.95, body, "Units", "normalized", ...
            "VerticalAlignment", "top", "HorizontalAlignment", "left", ...
            "FontName", paperCfg.fontName, "FontSize", paperCfg.fontSizeLegend, ...
            "Interpreter", "none");
    end
end

sgtitle(fig, "Best deploy methods by stop error (min)", ...
    "FontName", paperCfg.fontName, "FontSize", paperCfg.fontSizeTitle);

dpi = 300;
if isfield(cfg, "analysis") && isfield(cfg.analysis, "figureDpi")
    dpi = cfg.analysis.figureDpi;
end
exportPaperFigure(fig, outPath, "Resolution", dpi);

end

function txt = formatBestDeployCell(row, nDec)
if strlength(string(row.krMethodKey)) == 0
    txt = "No feasible method";
    return;
end

safePct = 100 * row.safeStopRate;
relMean = 100 * row.relativeStopError_success_mean;
relSem = 100 * row.relativeStopError_success_sem;
warmupSem = nan;
if ismember("warmupSteps_sem", row.Properties.VariableNames)
    warmupSem = row.warmupSteps_sem;
end

txt = sprintf("%s\nSafe-stop: %s%%\nStop MAE: %s ± %s N\nRel err: %s ± %s%%\nWarmup: %s ± %s steps\n(nFeasible=%d)", ...
    string(row.krMethodKey), ...
    formatPaperDecimal(safePct, nDec), ...
    formatPaperDecimal(row.stopMae_success, nDec), formatPaperDecimal(row.stopMae_success_sem, nDec), ...
    formatPaperDecimal(relMean, nDec), formatPaperDecimal(relSem, nDec), ...
    formatPaperDecimal(row.warmupStepsMean, nDec), formatPaperDecimal(warmupSem, nDec), ...
    row.nFeasible);
end

function paperCfg = resolvePaperTypography(cfg)
paperCfg = struct("fontName", "Times New Roman", "fontSizeLegend", 8, ...
    "fontSizeTitle", 11, "fontSizeSubtitle", 9.5);
if nargin < 1 || isempty(cfg)
    return;
end
if isfield(cfg, "paper")
    if isfield(cfg.paper, "fontName")
        paperCfg.fontName = cfg.paper.fontName;
    end
    if isfield(cfg.paper, "fontSizeLegend")
        paperCfg.fontSizeLegend = cfg.paper.fontSizeLegend;
    end
    if isfield(cfg.paper, "fontSizeTitle")
        paperCfg.fontSizeTitle = cfg.paper.fontSizeTitle;
    end
    if isfield(cfg.paper, "fontSizeSubtitle")
        paperCfg.fontSizeSubtitle = cfg.paper.fontSizeSubtitle;
    end
end
end
