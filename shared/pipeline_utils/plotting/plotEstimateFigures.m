function plotEstimateFigures(cfg, step)
%PLOTESTIMATEFIGURES 02_estimate 段階の figure 出力

if ~cfg.figures.enabled, return; end
pu = plotUtils();
figRoot = fullfile(cfg.out.estimate, "figures", step);
pu.ensureDir(figRoot);

switch step
    case "noise"
        plotNoise(cfg, pu, figRoot);
    case "yield"
        plotYield(cfg, pu, figRoot);
    case {"jeffreys", "burgers"}
        plotJeffreys(cfg, pu, figRoot);
    case "kr"
        plotKr(cfg, pu, figRoot);
    case "creep"
        plotCreep(cfg, pu, figRoot);
end
end

function plotNoise(cfg, pu, figRoot)
if ~isfile(cfg.paths.noiseProfile), return; end
sN = load(cfg.paths.noiseProfile, "noiseStats");
sD = load(cfg.paths.tomatoDataset, "tomatoData");
noiseStats = sN.noiseStats;
targetIds = noiseStats.targetIds;
fig = pu.newOffFigure("noise profile");
t = tiledlayout(fig, 1, numel(targetIds));
for k = 1:numel(targetIds)
    id = targetIds(k);
    idx = find([sD.tomatoData.id] == id, 1);
    if isempty(idx), continue; end
    y = sD.tomatoData(idx).yield;
    ax = nexttile(t);
    mask = y.sec >= 0 & y.sec <= 10;
    plot(ax, y.sec(mask), y.force(mask), "b.");
    title(ax, sprintf("ID %d", id)); xlabel(ax, "sec"); ylabel(ax, "force [N]");
    grid(ax, "on");
end
sgtitle(t, sprintf("Noise window (pooled sigma=%.4f N)", noiseStats.sigmaNoiseN));
pu.saveStageFigure(fig, figRoot, "01_noise_target_ids", cfg.figures);
end

function plotYield(cfg, pu, figRoot)
if ~isfile(cfg.paths.tomatoFiltered), return; end
s = load(cfg.paths.tomatoFiltered, "tomatoFiltered");
td = s.tomatoFiltered;
n = numel(td);
tilesPerPage = getTilesPerPage(cfg);
nCols = 4;
nRows = 3;
nPages = ceil(n / tilesPerPage);
for page = 1:nPages
    iStart = (page - 1) * tilesPerPage + 1;
    iEnd = min(page * tilesPerPage, n);
    nShow = iEnd - iStart + 1;
    fig = pu.newOffFigure("yield review", [50 50 1400 900]);
    t = tiledlayout(fig, nRows, nCols, "TileSpacing", "compact", "Padding", "compact");
    title(t, sprintf("Yield def-force (page %d/%d)", page, nPages));
    for si = 1:nShow
        i = iStart + si - 1;
        ax = nexttile(t);
        y = td(i).yield;
        [defAdj, forceAdj, ~] = zeroAdjustDefForceFirstPoint( ...
            y.deformation, y.force, getZeroAdjustEnabled(cfg));
        plot(ax, defAdj, forceAdj, "r.", "MarkerSize", 3); hold(ax, "on");
        yd = td(i).yieldDropThreshold;
        if isfield(yd, "hasYield") && yd.hasYield
            plot(ax, yd.deformation, yd.force, "kd", "MarkerSize", 6, "LineWidth", 1.2);
        end
        title(ax, sprintf("ID %d", td(i).id), "FontSize", 8);
        grid(ax, "on");
    end
    for si = (nShow + 1):tilesPerPage
        ax = nexttile(t);
        axis(ax, "off");
    end
    stem = pu.pagedFigureStem("01_yield_def_force_tiles", page, nPages);
    pu.saveStageFigure(fig, figRoot, stem, cfg.figures);
end
end

function plotJeffreys(cfg, pu, figRoot)
if ~isfile(cfg.paths.tomatoWithFit), return; end
s = load(cfg.paths.tomatoWithFit, "fitResults");
fr = s.fitResults;
ok = fr([fr.success]);
if isempty(ok), return; end
ids = [ok.id];
n = numel(ok);
tilesPerPage = getTilesPerPage(cfg);
nCols = 4;
nRows = 3;
nPages = ceil(n / tilesPerPage);
for page = 1:nPages
    iStart = (page - 1) * tilesPerPage + 1;
    iEnd = min(page * tilesPerPage, n);
    nShow = iEnd - iStart + 1;
    fig1 = pu.newOffFigure("jeffreys creep fit", [50 50 1400 900]);
    t1 = tiledlayout(fig1, nRows, nCols, "TileSpacing", "compact", "Padding", "compact");
    title(t1, sprintf("Jeffreys creep fit (page %d/%d)", page, nPages));
    for si = 1:nShow
        i = iStart + si - 1;
        ax = nexttile(t1);
        seg = ok(i).creepSegment;
        if isempty(seg.tSecRel), continue; end
        plot(ax, seg.tSecRel, seg.defMm, "k.", "MarkerSize", 3); hold(ax, "on");
        if isfield(seg, "yhatMm") && ~isempty(seg.yhatMm)
            plot(ax, seg.tSecRel, seg.yhatMm, "r-", "LineWidth", 1);
        end
        title(ax, sprintf("ID %d", ids(i)), "FontSize", 7); grid(ax, "on");
    end
    for si = (nShow + 1):tilesPerPage
        ax = nexttile(t1);
        axis(ax, "off");
    end
    stem = pu.pagedFigureStem("01_creep_fit_tiles", page, nPages);
    pu.saveStageFigure(fig1, figRoot, stem, cfg.figures);
end

fig2 = pu.newOffFigure("Jeffreys KC summary");
k2 = [ok.k2_retarded_N_per_mm]; c1 = [ok.c1_viscous_Ns_per_mm];
c2 = [ok.c2_retarded_Ns_per_mm];
t2 = tiledlayout(fig2, 1, 3);
nexttile(t2); histogram(k2); title("k_K"); nexttile(t2); histogram(c1); title("c_M");
nexttile(t2); histogram(c2); title("c_K");
pu.saveStageFigure(fig2, figRoot, "02_kc_parameter_summary", cfg.figures);
end

function plotKr(cfg, pu, figRoot)
plotKrSummary(cfg, pu, figRoot);
end

function plotCreep(cfg, pu, figRoot)
if ~isfile(cfg.paths.creepWaveforms), return; end
s = load(cfg.paths.creepWaveforms, "waveformMatrix", "waveformIds", "timeGrid");
X = s.waveformMatrix; ids = s.waveformIds; t = s.timeGrid;
nShow = min(12, size(X, 1));
fig = pu.newOffFigure("creep waveforms");
hold on;
for i = 1:nShow
    plot(t, X(i, :), "DisplayName", sprintf("ID %d", ids(i)));
end
xlabel("t [s] rel"); ylabel("def [mm]"); title("creep waveforms (sample)");
if nShow <= 8, legend("Location", "best"); end
grid on;
pu.saveStageFigure(fig, figRoot, "01_creep_waveform_overlay", cfg.figures);
end

function n = getTilesPerPage(cfg)
n = 12;
if isfield(cfg, "figures") && isfield(cfg.figures, "tilesPerPage") ...
        && isnumeric(cfg.figures.tilesPerPage) && isfinite(cfg.figures.tilesPerPage)
    n = max(1, round(cfg.figures.tilesPerPage));
end
end
