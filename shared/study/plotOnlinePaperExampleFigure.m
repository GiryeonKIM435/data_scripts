function plotOnlinePaperExampleFigure(sec, forceAbs, yTrue, yHat, alpha, tStop, ...
    forceLowN, forceHighN, titleStr, outPath, cfg, figOpts)
%plotOnlinePaperExampleFigure 論文用 online 例示図（単一 α）
%
% 黒実線 F(t)、黒破線 F_yield、水色帯 [lowN, highN)、
% 赤実線 ŷ(t)、赤破線 ŷ/α、紫破線 停止時刻。

if nargin < 11 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 12 || isempty(figOpts)
    figOpts = struct();
end
showTitle = false;
if isfield(figOpts, "showTitle")
    showTitle = logical(figOpts.showTitle);
end

T = numel(forceAbs);
sec = resolveDeployTimeAxisLocal(sec, T);
yHat = yHat(:);
forceAbs = forceAbs(:);
alpha = double(alpha);

fig = figure("Color", "w", "Position", [80 80 920 420], "Visible", "off");
ax = axes(fig);
hold(ax, "on");

hBand = gobjects(0);
hForce = gobjects(0);
hPred = gobjects(0);
hThr = gobjects(0);
hYield = gobjects(0);
hStop = gobjects(0);

% 剛性推定力区間（水色帯）— 背面に描く
if isfinite(forceLowN) && isfinite(forceHighN) && forceHighN > forceLowN
    xL = min(sec);
    xR = max(sec);
    if ~(isfinite(xL) && isfinite(xR)) || xR <= xL
        xL = 0;
        xR = max(T - 1, 1);
    end
    bandColor = [0.70, 0.88, 0.95];
    hBand = patch(ax, [xL xR xR xL], [forceLowN forceLowN forceHighN forceHighN], ...
        bandColor, "EdgeColor", "none", "FaceAlpha", 0.45);
end

hForce = plot(ax, sec, forceAbs, "k-", "LineWidth", 1.3);

[~, thrPlot, thrIdx] = prepareQ3DeployStopDisplay(yHat, alpha, tStop);
validY = isfinite(yHat);
if any(validY)
    hPred = plot(ax, sec(validY), yHat(validY), "-", "Color", [0.85 0.10 0.10], ...
        "LineWidth", 1.2);
end

thrSlice = thrPlot(thrIdx);
secSlice = sec(thrIdx);
validThr = isfinite(thrSlice);
if any(validThr)
    hThr = plot(ax, secSlice(validThr), thrSlice(validThr), "--", ...
        "Color", [0.85 0.10 0.10], "LineWidth", 1.1);
end

hYield = plot(ax, nan, nan, "k--", "LineWidth", 1.2);
yline(ax, yTrue, "k--", "LineWidth", 1.2, "HandleVisibility", "off");

purple = [0.49 0.18 0.56];
if isfinite(tStop) && tStop >= 1 && tStop <= T
    xline(ax, sec(round(tStop)), "--", "Color", purple, "LineWidth", 1.6, ...
        "HandleVisibility", "off");
    hStop = plot(ax, nan, nan, "--", "Color", purple, "LineWidth", 1.6);
end

grid(ax, "on");
xlabel(ax, "Time (s)");
ylabel(ax, "Force (N)");
if showTitle && nargin >= 9 && strlength(string(titleStr)) > 0
    title(ax, titleStr, "Interpreter", "none");
end

% y 軸: 0 N 起点
yVals = [forceAbs(:); yTrue; yHat(isfinite(yHat))];
if isfinite(forceLowN)
    yVals(end + 1, 1) = forceLowN; %#ok<AGROW>
end
if isfinite(forceHighN)
    yVals(end + 1, 1) = forceHighN; %#ok<AGROW>
end
yVals = yVals(isfinite(yVals));
if ~isempty(yVals)
    yMax = max(yVals);
    if ~(isfinite(yMax) && yMax > 0)
        yMax = 1;
    end
    ylim(ax, [0, yMax * 1.05]);
end

% 共有凡例（上部）
legHandles = gobjects(0);
legLabels = {};
if isfinite(forceLowN) && isfinite(forceHighN) && isgraphics(hBand)
    legHandles(end + 1) = hBand; %#ok<AGROW>
    legLabels{end + 1} = sprintf("Stiffness band [%.0f, %.0f) N", forceLowN, forceHighN); %#ok<AGROW>
end
if isgraphics(hForce)
    legHandles(end + 1) = hForce; %#ok<AGROW>
    legLabels{end + 1} = "Measured force"; %#ok<AGROW>
end
if isgraphics(hYield)
    legHandles(end + 1) = hYield; %#ok<AGROW>
    legLabels{end + 1} = "True yield"; %#ok<AGROW>
end
if isgraphics(hPred)
    legHandles(end + 1) = hPred; %#ok<AGROW>
    legLabels{end + 1} = "Predicted yield"; %#ok<AGROW>
end
if isgraphics(hThr)
    legHandles(end + 1) = hThr; %#ok<AGROW>
    legLabels{end + 1} = '\hat{F}_{yield}/\alpha_{0.95}'; %#ok<AGROW>
end
if isgraphics(hStop)
    legHandles(end + 1) = hStop; %#ok<AGROW>
    legLabels{end + 1} = "Stop time"; %#ok<AGROW>
end
if ~isempty(legHandles)
    lgd = legend(ax, legHandles, legLabels, "Interpreter", "tex", ...
        "FontSize", 9, "Orientation", "horizontal", "Location", "northoutside");
end

exportPaperFigure(fig, outPath, "Resolution", cfg.analysis.figureDpi);
end

function sec = resolveDeployTimeAxisLocal(sec, T)
sec = sec(:);
if numel(sec) < T
    padDt = median(diff(sec(max(1, end-1):end)), "omitnan");
    if ~isfinite(padDt) || padDt <= 0
        padDt = 1;
    end
    sec = [sec; sec(end) + (1:(T - numel(sec)))' * padDt];
elseif numel(sec) > T
    sec = sec(1:T);
end
if isempty(sec) || any(~isfinite(sec))
    sec = (0:T-1)';
end
end
