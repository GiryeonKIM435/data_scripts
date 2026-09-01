function plotQ3DeployForceTimeFigure(sec, forceAbs, yTrue, yHat, alpha, tStop, titleStr, outPath, cfg)
%plotQ3DeployForceTimeFigure Q3 デプロイ力–時間図（論文 fig4 / test diagnostics 共通）

if nargin < 9 || isempty(cfg)
    cfg = PaperStudyConfig();
end

T = numel(forceAbs);
sec = resolveDeployTimeAxis(sec, T);

fig = figure("Color", "w", "Position", [80 80 900 460], "Visible", "off");
ax = axes(fig);
hold(ax, "on");

plot(ax, sec, forceAbs, "k-", "LineWidth", 1.2, "DisplayName", "Measured force");

validY = isfinite(yHat);
yHatColor = [1, 0, 0];
if any(validY)
    [yPlot, thrPlot, thrIdx] = prepareQ3DeployStopDisplay(yHat, alpha, tStop);
    validPlot = isfinite(yHat);
    if any(validPlot)
        plot(ax, sec(validPlot), yHat(validPlot), "-", "Color", yHatColor, "LineWidth", 1.1, ...
            "DisplayName", "Predicted yield (LOO calib.)");
    end
    if isfinite(tStop) && tStop >= 1 && tStop <= T
        postIdx = round(tStop):T;
        postY = yPlot(postIdx);
        postSec = sec(postIdx);
        validPost = isfinite(postY);
        if any(validPost)
            plot(ax, postSec(validPost), postY(validPost), "-", "Color", [0.00, 0.45, 0.74], ...
                "LineWidth", 1.1, "DisplayName", "Predicted yield after stop");
        end
    end
    thrSlice = thrPlot(thrIdx);
    secSlice = sec(thrIdx);
    validThr = isfinite(thrSlice);
    if any(validThr)
        plot(ax, secSlice(validThr), thrSlice(validThr), "c--", "LineWidth", 1.0, ...
            "DisplayName", sprintf("Stop threshold (\\hat{y}/%.1f)", alpha));
    end
end

plot(ax, nan, nan, "r--", "LineWidth", 1.2, "DisplayName", "True yield");
yline(ax, yTrue, "r--", "LineWidth", 1.2, "HandleVisibility", "off");

if isfinite(tStop) && tStop >= 1 && tStop <= T
    xline(ax, sec(tStop), "m--", "LineWidth", 1.5, "HandleVisibility", "off");
    plot(ax, nan, nan, "m--", "LineWidth", 1.5, "DisplayName", "Stop time");
end

grid(ax, "on");
xlabel(ax, "Time [s]");
ylabel(ax, "Force [N]");
title(ax, titleStr, "Interpreter", "none");
legend(ax, "Location", "best");

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
