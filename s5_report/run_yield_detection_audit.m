function results = run_yield_detection_audit(cfg, opts)
%RUN_YIELD_DETECTION_AUDIT Methods: bioyield detection rules + example curves
%
% Matches paper Methods (mechanical bioyield force F_Y):
%   - L=5 force-drop detection defines F_Y
%   - Subsequent QC is author visual exclusion
% Figure: one accepted example + two visually excluded panels.

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end

cfg = ensureDetectYieldCfg(cfg);

outDir = fullfile(cfg.out.root, "sec4_yield_detection");
if ~isfolder(outDir)
    mkdir(outDir);
end
figDir = cfg.out.paperFigures;
tabDir = cfg.out.paperTables;

%% ルール文書（論文 Methods と対応）
if ~isfile(cfg.paths.noiseProfile)
    error("run_yield_detection_audit:NoNoise", "noise_profile.mat がありません。");
end
sN = load(cfg.paths.noiseProfile, "noiseStats");
sigma = sN.noiseStats.sigmaNoiseN;
noiseIds = cfg.detectYield.noiseTargetIds;
zeroAdj = getZeroAdjustEnabled(cfg);
T = 3 * sigma + 0.01;

rulesPath = fullfile(outDir, "yield_detection_rules.txt");
fid = fopen(rulesPath, "w", "n", "UTF-8");
fprintf(fid, "Bioyield detection rules (paper Methods; L=5 single exceed + visual QC)\n");
fprintf(fid, "================================================================================\n\n");
fprintf(fid, "0. Preprocessing\n");
fprintf(fid, "   - Zero adjustment: first valid (def, force) point shifted to origin");
if zeroAdj
    fprintf(fid, " (ENABLED)\n");
else
    fprintf(fid, " (DISABLED)\n");
end
fprintf(fid, "   - No low-pass filtering\n");
fprintf(fid, "   - Noise SD sigma_noise = %.6f N (pooled from target IDs: %s)\n", ...
    sigma, mat2str(noiseIds(:).'));
fprintf(fid, "   - Force resolution = 0.01 N\n");
fprintf(fid, "   - Threshold T = 3*sigma_noise + 0.01 = %.6f N\n\n", T);
fprintf(fid, "1. Automatic detection (paper criterion)\n");
fprintf(fid, "   - Look-ahead L = 5 samples (50 ms at 100 Hz)\n");
fprintf(fid, "   - Force drop: deltaF_i^(5) = F_i - F_{i+5}\n");
fprintf(fid, "   - First sample with deltaF_i^(5) > T and F_i >= 1 N is the bioyield point\n");
fprintf(fid, "   - F_yield = force at that sample\n");
fprintf(fid, "   - Multiple drops: earliest qualifying event (first-hit)\n\n");
fprintf(fid, "2. Visual quality control\n");
fprintf(fid, "   - After automatic detection, each force-deformation curve is inspected by the authors\n");
fprintf(fid, "   - Fruits without a clear force drop are excluded from subsequent analyses\n");
fclose(fid);
copyfile(rulesPath, fullfile(tabDir, "yield_detection_rules.txt"));

%% データ読込
if ~isfile(cfg.paths.tomatoDataset)
    error("run_yield_detection_audit:NoDataset", "tomato_dataset.mat がありません。");
end
sD = load(cfg.paths.tomatoDataset, "tomatoData");
tomatoData = sD.tomatoData;
n = numel(tomatoData);
ids = [tomatoData.id];

hasYield = false(1, n);
yDef = nan(1, n);
yForce = nan(1, n);
for i = 1:n
    y = tomatoData(i).yield;
    [defAdj, forceAdj, ~] = zeroAdjustDefForceFirstPoint( ...
        y.deformation, y.force, zeroAdj);
    % 論文基準: L=5 single exceed（detectYieldPoints の Method B）
    [~, ~, ~, hs, dSe, fSe] = detectYieldPoints(defAdj, forceAdj, sigma);
    hasYield(i) = hs;
    yDef(i) = dSe;
    yForce(i) = fSe;
end

% 目視除外 ID: tomato_filtered の除外リストを優先（論文の2果と一致）
[keptIds, excludedIds] = resolveVisualExclusionIds(cfg, ids, hasYield);

%% 代表図: 採用1 + 目視除外2
acceptedId = pickFirstId(ids, ismember(ids, keptIds) & hasYield);
if ~isfinite(acceptedId)
    acceptedId = pickFirstId(ids, hasYield);
end

exclPanelIds = excludedIds(:)';
if isempty(exclPanelIds)
    exclPanelIds = nan(0, 1);
end
% 最大2例（論文図の中央・右）
exclPanelIds = exclPanelIds(1:min(2, numel(exclPanelIds)));

panels = cell(0, 2);
panels(end + 1, :) = {acceptedId, "(a) Accepted"}; %#ok<AGROW>
for k = 1:numel(exclPanelIds)
    tag = ternary(k == 1, "(b) Visually excluded", "(c) Visually excluded");
    panels(end + 1, :) = {exclPanelIds(k), tag}; %#ok<AGROW>
end
panels = panels(~cellfun(@(x) isempty(x) || ~isfinite(x), panels(:, 1)), :);

nP = size(panels, 1);
nCols = min(3, max(1, nP));
nRows = ceil(nP / nCols);
fig = figure("Color", "w", "Position", [60 60 420 * nCols, 360 * nRows], "Visible", "off");
tl = tiledlayout(fig, nRows, nCols, "Padding", "compact", "TileSpacing", "compact");

hLegMeas = gobjects(0);
hLegYield = gobjects(0);
for pi = 1:nP
    ax = nexttile(tl);
    id = panels{pi, 1};
    idx = find(ids == id, 1);
    y = tomatoData(idx).yield;
    [defAdj, forceAdj, ~] = zeroAdjustDefForceFirstPoint( ...
        y.deformation, y.force, zeroAdj);
    hMeas = plot(ax, defAdj, forceAdj, ".", "MarkerSize", 4, ...
        "Color", [0.75 0.2 0.2]);
    hold(ax, "on");
    if hasYield(idx)
        hY = plot(ax, yDef(idx), yForce(idx), "kd", ...
            "MarkerSize", 7, "LineWidth", 1.2, "MarkerFaceColor", [0.95 0.95 0.2]);
        if isempty(hLegMeas)
            hLegMeas = hMeas;
            hLegYield = hY;
        end
    elseif isempty(hLegMeas)
        hLegMeas = hMeas;
    end
    grid(ax, "on");
    xlabel(ax, "Deformation (mm)");
    ylabel(ax, "Force (N)");
    title(ax, sprintf("ID %d: %s", id, panels{pi, 2}), ...
        "FontSize", 9, "Interpreter", "none");
    yMax = max(forceAdj(isfinite(forceAdj)), [], "omitnan");
    if ~(isfinite(yMax) && yMax > 0)
        yMax = 1;
    end
    ylim(ax, [0, yMax * 1.05]);
end

if ~isempty(hLegMeas) && isgraphics(hLegMeas)
    if ~isempty(hLegYield) && isgraphics(hLegYield)
        lgd = legend([hLegMeas, hLegYield], ...
            {"measurement", "$F_{\mathrm{yield}}$"}, ...
            "Interpreter", "latex", "FontSize", 9, "Orientation", "horizontal");
    else
        lgd = legend(hLegMeas, {"measurement"}, ...
            "Interpreter", "none", "FontSize", 9, "Orientation", "horizontal");
    end
    lgd.Layout.Tile = "north";
end

figPath = fullfile(outDir, "fig_yield_detection_examples.png");
exportPaperFigure(fig, figPath, "Resolution", 300);  % 内部で close 済み
copyfile(figPath, fullfile(figDir, "fig_yield_detection_examples.png"));
if isfile(strrep(figPath, ".png", ".fig"))
    copyfile(strrep(figPath, ".png", ".fig"), fullfile(figDir, "fig_yield_detection_examples.fig"));
end

%% 集計表（論文: 103 → 目視除外2 → 101）
nKept = numel(keptIds);
nExcl = numel(excludedIds);
summaryTbl = table( ...
    n, sum(hasYield), nExcl, nKept, ...
    {mat2str(excludedIds(:).')}, ...
    'VariableNames', {'nSource', 'nDetected', 'nVisualExcluded', 'nKept', 'visualExcludedIds'});
writetable(summaryTbl, fullfile(outDir, "table_yield_detection_filter_counts.csv"));
writetable(summaryTbl, fullfile(tabDir, "table_yield_detection_filter_counts.csv"));

results = struct();
results.createdAt = datetime("now");
results.rulesPath = rulesPath;
results.figPath = figPath;
results.summary = summaryTbl;
results.sigmaNoiseN = sigma;
results.acceptedId = acceptedId;
results.visualExcludedIds = excludedIds(:).';
fprintf("Yield detection audit: kept=%d/%d, visual-excl=%d -> %s\n", ...
    nKept, n, nExcl, outDir);
end

function [keptIds, excludedIds] = resolveVisualExclusionIds(cfg, allIds, hasYield)
%RESOLVEVISUALEXCLUSIONIDS 目視除外 ID を filtered 成果物またはフォールバックから取得
keptIds = [];
excludedIds = [];
if isfield(cfg.paths, "tomatoFiltered") && isfile(cfg.paths.tomatoFiltered)
    sF = load(cfg.paths.tomatoFiltered, "tomatoFiltered", "metadataFiltered");
    if isfield(sF, "metadataFiltered") ...
            && isfield(sF.metadataFiltered, "keptIds") ...
            && isfield(sF.metadataFiltered, "excludedIds")
        keptIds = sF.metadataFiltered.keptIds(:).';
        excludedIds = sF.metadataFiltered.excludedIds(:).';
        return;
    end
    if isfield(sF, "tomatoFiltered")
        keptIds = [sF.tomatoFiltered.id].';
        excludedIds = setdiff(allIds(:), keptIds, "stable");
        return;
    end
end
% フォールバック: 検出成功を採用、検出失敗を除外扱い
keptIds = allIds(hasYield);
excludedIds = allIds(~hasYield);
end

function id = pickFirstId(ids, mask)
id = nan;
ix = find(mask, 1, "first");
if ~isempty(ix)
    id = ids(ix);
end
end

function out = ternary(cond, a, b)
if cond
    out = a;
else
    out = b;
end
end

function cfg = ensureDetectYieldCfg(cfg)
%ensureDetectYieldCfg PaperStudyConfig に無い detectYield を PipelineConfig から補完
if isfield(cfg, "detectYield") && isfield(cfg.detectYield, "noiseTargetIds")
    return;
end
pipe = PipelineConfig();
cfg.detectYield = pipe.detectYield;
end
