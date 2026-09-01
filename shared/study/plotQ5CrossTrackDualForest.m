function plotQ5CrossTrackDualForest(crossSummary, outPath, cfg, plotOpts)
%plotQ5CrossTrackDualForest offline/online 横並び ΔMAE 森林プロット
%
% crossSummary: buildQ5CrossTrackSummary 出力

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 4 || isempty(plotOpts)
    plotOpts = struct();
end
if isempty(crossSummary)
    return;
end

labels = getQ5ModelCaseLabels(cfg);
caseIds = string(crossSummary.caseId);
displayLabels = strings(height(crossSummary), 1);
for i = 1:height(crossSummary)
    idx = find(string(getQ5ModelCaseOrder(cfg)) == caseIds(i), 1);
    if ~isempty(idx)
        displayLabels(i) = labels(idx);
    else
        displayLabels(i) = caseIds(i);
    end
end

n = height(crossSummary);
offColor = [0.00, 0.45, 0.74];
onColor = [0.85, 0.33, 0.10];
xOff = (1:n)' - 0.18;
xOn = (1:n)' + 0.18;

figW = max(900, 120 * n);
fig = figure("Color", "w", "Position", [80 80 figW 560], "Visible", "off");
hold on;

errorbar(xOff, crossSummary.deltaMae_offlineLoocv, ...
    crossSummary.deltaMae_offlineLoocv - crossSummary.ciDeltaMaeLo_offline, ...
    crossSummary.ciDeltaMaeHi_offline - crossSummary.deltaMae_offlineLoocv, ...
    "o", "Color", offColor, "MarkerFaceColor", offColor, ...
    "LineWidth", 1.2, "MarkerSize", 7, "CapSize", 8, ...
    "DisplayName", "Offline LOOCV");
errorbar(xOn, crossSummary.deltaMae_onlineDeploy, ...
    crossSummary.deltaMae_onlineDeploy - crossSummary.ciDeltaMaeLo_online, ...
    crossSummary.ciDeltaMaeHi_online - crossSummary.deltaMae_onlineDeploy, ...
    "o", "Color", onColor, "MarkerFaceColor", onColor, ...
    "LineWidth", 1.2, "MarkerSize", 7, "CapSize", 8, ...
    "DisplayName", "Online deploy");

yline(0, "k--", "LineWidth", 1.0);
set(gca, "XTick", 1:n, "XTickLabel", cellstr(displayLabels), "XTickLabelRotation", 45);
ylabel("\DeltaMAE vs M0 [N]");
if isfield(plotOpts, "title") && strlength(string(plotOpts.title)) > 0
    title(char(plotOpts.title));
else
    title("Cross-track predictor contribution");
end
grid on;
legend("Location", "best");

yVals = [crossSummary.deltaMae_offlineLoocv; crossSummary.deltaMae_onlineDeploy; ...
    crossSummary.ciDeltaMaeLo_offline; crossSummary.ciDeltaMaeHi_offline; ...
    crossSummary.ciDeltaMaeLo_online; crossSummary.ciDeltaMaeHi_online];
yRange = max(yVals, [], "omitnan") - min(yVals, [], "omitnan");
if ~isfinite(yRange) || yRange == 0
    yRange = max(abs(yVals), [], "omitnan");
end
yPad = 0.14 * max(yRange, 0.5);
yTop = max(yVals, [], "omitnan");

for i = 1:n
    yOff = max(crossSummary.deltaMae_offlineLoocv(i), crossSummary.ciDeltaMaeHi_offline(i)) + yPad;
    yOn = max(crossSummary.deltaMae_onlineDeploy(i), crossSummary.ciDeltaMaeHi_online(i)) + yPad;
    text(xOff(i), yOff, formatPqAnnotation( ...
        crossSummary.pBootstrap_offline(i), crossSummary.qValueBH_offline(i)), ...
        "HorizontalAlignment", "center", "FontSize", 8, "Color", offColor);
    text(xOn(i), yOn, formatPqAnnotation( ...
        crossSummary.pBootstrap_online(i), crossSummary.qValueBH_online(i)), ...
        "HorizontalAlignment", "center", "FontSize", 8, "Color", onColor);
    yTop = max([yTop, yOff, yOn]);
end
ylim([min(yVals, [], "omitnan") - yPad, yTop + yPad]);

dpi = cfg.analysis.figureDpi;
if isfield(plotOpts, "dpi") && ~isempty(plotOpts.dpi)
    dpi = plotOpts.dpi;
end
exportPaperFigure(fig, outPath, "Resolution", dpi);
end

function txt = formatPqAnnotation(pVal, qVal)
txt = formatStatLabel("p", pVal);
if isfinite(qVal)
    txt = sprintf("%s\n%s", txt, formatStatLabel("q", qVal));
end
end

function txt = formatStatLabel(prefix, v)
%formatStatLabel 小数2桁。0.01未満は <0.01（p=/q= を二重にしない）
if ~isfinite(v)
    txt = sprintf("%s=NA", prefix);
    return;
end
if v < 0.01
    txt = sprintf("%s<0.01", prefix);
else
    txt = sprintf("%s=%.2f", prefix, v);
end
end
