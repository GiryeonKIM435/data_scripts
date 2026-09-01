function retention = plotOfflineOnlineRetention(q1Summary, designSummary, cfg, outDir)
%plotOfflineOnlineRetention 結果4.3: オフライン性能のオンライン実現度
%
% 初期荷重域（force_abs）30 条件について、
%   x = オフライン LOOCV MAE、y = オンライン Final-update MAE
% の散布図（y=x 線付き）と保持率テーブル CSV を出力する。

retention = table();
if isempty(q1Summary) || ~istable(q1Summary) || height(q1Summary) == 0
    warning("plotOfflineOnlineRetention:NoQ1", ...
        "オフライン LOOCV 結果（4.2 doOffline）がありません。スキップします。");
    return;
end
if ~isfolder(outDir)
    mkdir(outDir);
end

krVariant = string(cfg.deploy.krVariant);
q1sub = q1Summary;
if ismember("variant", q1sub.Properties.VariableNames)
    q1sub = q1sub(string(q1sub.variant) == krVariant, :);
end
q1sub = q1sub(string(q1sub.methodType) == "force_abs", :);

onSub = designSummary(string(designSummary.methodType) == "force_abs", :);
maeField = "finalUpdateMae_bootMean_b5000";
if ~ismember(maeField, onSub.Properties.VariableNames)
    maeField = "finalUpdateMae";
end

keys = intersect(string(q1sub.krMethodKey), string(onSub.krMethodKey), "stable");
n = numel(keys);
if n == 0
    warning("plotOfflineOnlineRetention:NoOverlap", ...
        "オフライン/オンラインで共通の方式がありません。スキップします。");
    return;
end

offMae = nan(n, 1);
onMae = nan(n, 1);
safeRate = nan(n, 1);
alphaDesign = nan(n, 1);
nFail = nan(n, 1);
labels = strings(n, 1);
for i = 1:n
    qi = find(string(q1sub.krMethodKey) == keys(i), 1);
    oi = find(string(onSub.krMethodKey) == keys(i), 1);
    offMae(i) = q1sub.mae_loocv(qi);
    onMae(i) = onSub.(maeField)(oi);
    labels(i) = string(q1sub.label(qi));
    if ismember("safeStopRate", onSub.Properties.VariableNames)
        safeRate(i) = onSub.safeStopRate(oi);
    end
    if ismember("alphaDesign", onSub.Properties.VariableNames)
        alphaDesign(i) = onSub.alphaDesign(oi);
    end
    if ismember("nSafeStopFail", onSub.Properties.VariableNames)
        nFail(i) = onSub.nSafeStopFail(oi);
    end
end

retention = table(keys, labels, offMae, onMae, onMae ./ offMae, ...
    safeRate, alphaDesign, nFail, ...
    'VariableNames', {'krMethodKey', 'label', 'offlineMaeLoocv', 'onlineFinalUpdateMae', ...
    'maeRatio_onlineToOffline', 'safeStopRate', 'alphaDesign', 'nSafeStopFail'});
retention = sortrows(retention, "onlineFinalUpdateMae", "ascend");
writetable(retention, fullfile(outDir, "offline_online_retention_force_abs.csv"));

dpi = 300;
if isfield(cfg, "analysis") && isfield(cfg.analysis, "figureDpi")
    dpi = cfg.analysis.figureDpi;
end

fig = figure("Color", "w", "Position", [80 80 620 560], "Visible", "off");
ax = axes(fig);
scatter(ax, offMae, onMae, 46, "filled");
hold(ax, "on");
lims = [min([offMae; onMae], [], "omitnan"), max([offMae; onMae], [], "omitnan")];
pad = 0.05 * (lims(2) - lims(1));
lims = lims + [-pad, pad];
plot(ax, lims, lims, "k--", "DisplayName", "y = x");
xlim(ax, lims);
ylim(ax, lims);

[~, bi] = min(onMae);
if isfinite(bi)
    text(ax, offMae(bi), onMae(bi), "  " + shortMethodLabel(keys(bi)), ...
        "FontSize", 8, "Color", [0.85 0.1 0.1], "FontWeight", "bold");
    scatter(ax, offMae(bi), onMae(bi), 70, [0.85 0.1 0.1]);
end

xlabel(ax, "Offline LOOCV MAE [N]");
ylabel(ax, "Online Final-update MAE [N]");
title(ax, "Offline vs online performance (force\\_abs, \\alpha_{0.95})");
grid(ax, "on");
axis(ax, "square");

outPath = fullfile(outDir, "fig4_3_offline_online_retention.png");
exportPaperFigure(fig, outPath, "Resolution", dpi);

end

function s = shortMethodLabel(key)
s = string(key);
s = erase(s, "force_");
end
