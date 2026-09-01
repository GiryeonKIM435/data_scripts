function plotQ3DeployForceTimeMultiAlphaFigure(sec, forceAbs, yTrue, yHat, alphaValues, tStopVec, titleStr, outPath, cfg, figOpts)
%plotQ3DeployForceTimeMultiAlphaFigure 複数安全率 α の Q3 デプロイ力–時間図（論文 fig4）

if nargin < 9 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 10 || isempty(figOpts)
    figOpts = struct();
end
showLegend = true;
if isfield(figOpts, "showLegend")
    showLegend = logical(figOpts.showLegend);
end

T = numel(forceAbs);
sec = resolveDeployTimeAxis(sec, T);
alphaValues = alphaValues(:);
tStopVec = tStopVec(:);
if numel(tStopVec) ~= numel(alphaValues)
    error("plotQ3DeployForceTimeMultiAlphaFigure:SizeMismatch", ...
        "tStopVec の長さは alphaValues と一致する必要があります。");
end

colors = [
    0.49, 0.18, 0.56;
    0.00, 0.45, 0.74;
    0.85, 0.33, 0.10;
    0.47, 0.67, 0.19];
if numel(alphaValues) > size(colors, 1)
    colors = parula(numel(alphaValues));
end
yHatColor = [1, 0, 0];

fig = figure("Color", "w", "Position", [80 80 920 500], "Visible", "off");
ax = axes(fig);
hold(ax, "on");

plot(ax, sec, forceAbs, "k-", "LineWidth", 1.2, "DisplayName", "Measured force");

yHat = yHat(:);
validYMain = isfinite(yHat);
if any(validYMain)
    plot(ax, sec(validYMain), yHat(validYMain), "-", "Color", yHatColor, "LineWidth", 1.1, ...
        "DisplayName", "Predicted yield");
end

for ai = 1:numel(alphaValues)
    alpha = alphaValues(ai);
    col = colors(ai, :);
    [yPlot, thrPlot, thrIdx] = prepareQ3DeployStopDisplay(yHat, alpha, tStopVec(ai));

    tStop = tStopVec(ai);
    if isfinite(tStop) && tStop >= 1 && tStop <= T
        postIdx = round(tStop):T;
        postY = yPlot(postIdx);
        postSec = sec(postIdx);
        validPost = isfinite(postY);
        if any(validPost)
            plot(ax, postSec(validPost), postY(validPost), "-", "Color", col, "LineWidth", 1.1, ...
                "DisplayName", sprintf("Predicted yield after stop (\\alpha=%.3f)", alpha));
        end
    end

    thrSlice = thrPlot(thrIdx);
    secSlice = sec(thrIdx);
    validThr = isfinite(thrSlice);
    if any(validThr)
        plot(ax, secSlice(validThr), thrSlice(validThr), "--", "Color", col, "LineWidth", 1.0, ...
            "DisplayName", sprintf("Stop threshold (\\hat{y}/%.3f)", alpha));
    end

    if isfinite(tStop) && tStop >= 1 && tStop <= T
        xline(ax, sec(round(tStop)), "--", "Color", col, "LineWidth", 1.5, "HandleVisibility", "off");
        plot(ax, nan, nan, "--", "Color", col, "LineWidth", 1.5, ...
            "DisplayName", sprintf("Stop time (\\alpha=%.3f)", alpha));
    end
end

plot(ax, nan, nan, "r--", "LineWidth", 1.2, "DisplayName", "True yield");
yline(ax, yTrue, "r--", "LineWidth", 1.2, "HandleVisibility", "off");

grid(ax, "on");
xlabel(ax, "Time [s]");
ylabel(ax, "Force [N]");
title(ax, titleStr, "Interpreter", "none");
if showLegend
    legend(ax, "Location", "best");
end

exportPaperFigure(fig, outPath, "Resolution", cfg.analysis.figureDpi);

end

function sec = resolveDeployTimeAxis(sec, T)
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
