function out = plotQ3OnlineStopYieldScatter(cfg, q3Deploy, figDir)
%plotQ3OnlineStopYieldScatter Q3 オンライン停止時予測 vs 実測（fig2c）

out = struct();
out.path = "";
out.skipped = true;

if nargin < 3 || ~isfolder(figDir)
    mkdir(figDir);
end

methodKey = cfg.paper.exampleMethodKey;
alpha = cfg.deploy.primaryAlpha;
if isfield(cfg.paper, "exampleAlpha") && isfinite(cfg.paper.exampleAlpha)
    alpha = cfg.paper.exampleAlpha;
end
nDec = cfg.paper.tableDecimals;

perSample = loadQ3PerSampleTable(cfg, q3Deploy);
if isempty(perSample)
    warning("plotQ3OnlineStopYieldScatter:NoData", ...
        "Q3 per-sample データがありません。fig2c をスキップします。");
    return;
end

sub = perSample(string(perSample.krMethodKey) == string(methodKey) ...
    & abs(perSample.alpha - alpha) < 1e-9 ...
    & string(perSample.outcome) == "success", :);
yTrue = sub.yTrue(:);
yPred = sub.y_hat_at_stop(:);
valid = isfinite(yTrue) & isfinite(yPred);
yTrue = yTrue(valid);
yPred = yPred(valid);

if numel(yTrue) < 2
    warning("plotQ3OnlineStopYieldScatter:InsufficientData", ...
        "fig2c: safe-stop 成功試料が不足しています (n=%d)。", numel(yTrue));
    return;
end

metrics = calcMetrics(yTrue, yPred);
maePct = mean(abs(yTrue - yPred) ./ abs(yTrue)) * 100;

outPath = fullfile(figDir, "fig2c_online_stop_yield_scatter.png");
fig = figure("Color", "w", "Position", [80 80 520 480], "Visible", "off");
scatter(yTrue, yPred, 36, "filled"); hold on;
lims = [min(yTrue), max(yTrue)];
plot(lims, lims, "k--");
xlabel("Observed yield [N]");
ylabel("Predicted yield at stop [N]");
title(sprintf("Online deploy (%s, \\alpha=%.1f)", methodKey, alpha));
subtitle(sprintf("MAE=%s N (%s%%), RMSE=%s N, R^2=%s, n=%d", ...
    formatPaperDecimal(metrics.mae, nDec), ...
    formatPaperDecimal(maePct, nDec), ...
    formatPaperDecimal(metrics.rmse, nDec), ...
    formatPaperDecimal(metrics.r2, nDec), ...
    metrics.n));
grid on;
exportPaperFigure(fig, outPath, "Resolution", cfg.analysis.figureDpi);

out.path = outPath;
out.skipped = false;
out.methodKey = char(string(methodKey));
out.alpha = alpha;
out.metrics = metrics;
out.maePct = maePct;
out.n = metrics.n;

end

function perSample = loadQ3PerSampleTable(cfg, q3Deploy)
perSample = table();

if nargin >= 2 && ~isempty(q3Deploy) && isfield(q3Deploy, "perSampleTable")
    perSample = q3Deploy.perSampleTable;
    if ~isempty(perSample)
        return;
    end
end

q3Tag = resolvePaperQ3AnalysisTag(cfg);
csvPath = fullfile(cfg.out.q3, q3Tag, "streaming_deploy_per_sample.csv");
if ~isfile(csvPath)
    return;
end
perSample = readtable(csvPath);

end
