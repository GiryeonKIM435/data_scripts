function out = evalStopAlphas(traj, alpha, yTrue)
%evalStopAlphas 軌跡から停止規則 F_abs>=y_hat/alpha を事後評価
%
% 安全停止（outcome, t_stop, stopErrorN）に加え、Final-update MAE 用に
% 評価上限 min(t_alpha_stop, t_yield, t_end) 以前の最終予測更新時点の
% 誤差（finalUpdateErrorN）を常に算出する。

alpha = double(alpha);
yTrue = double(yTrue);
T = traj.nSteps;
if ~(isfinite(alpha) && alpha > 0)
    error("evalStopAlphas:InvalidAlpha", ...
        "alpha は正の有限値である必要があります。alpha=%.6g", alpha);
end

if isfield(traj, "forceAbs")
    forceEval = traj.forceAbs(:);
else
    forceEval = traj.force(:);
end

out = struct();
out.outcome = "";
out.yTrue = yTrue;
out.alpha = alpha;
out.F_stop = nan;
out.t_stop = nan;
out.y_hat_at_stop = nan;
out.kr_at_stop = nan;
out.F_lastUpdate = nan;
out.F_used = nan;
out.nStepsToFirstKr = traj.firstKrStep;
out.secToFirstKr = traj.firstKrSec;
out.hadValidKr = any(traj.hadValidKr);
out.nStepsTotal = T;
out.stopErrorN = nan;
out.relativeStopError = nan;
out.isSafeStop = false;
out.stoppingMargin = nan;   % (yTrue - F_stop) / yTrue（成功時）
out.stopForceRatio = nan;   % F_stop / yTrue（成功時）
out.t_finalUpdate = nan;
out.F_finalUpdate = nan;
out.y_hat_finalUpdate = nan;
out.finalUpdateErrorN = nan;
out.relativeFinalUpdateError = nan;

tYieldEnd = T;
if isfinite(traj.crossStep)
    tYieldEnd = traj.crossStep - 1;
end

lastT = tYieldEnd;

for t = 1:lastT
    if traj.hadValidKr(t) && isfinite(traj.yHat(t)) && forceEval(t) >= traj.yHat(t) / alpha
        out.outcome = "success";
        out.t_stop = t;
        out.F_stop = forceEval(t);
        out.y_hat_at_stop = traj.yHat(t);
        out.kr_at_stop = resolveTrajectoryKrAt(traj, t);
        out.stopErrorN = abs(out.y_hat_at_stop - yTrue);
        out.relativeStopError = calcRelativeError(out.y_hat_at_stop, yTrue);
        out.isSafeStop = true;
        if isfinite(yTrue) && abs(yTrue) > 0 && isfinite(out.F_stop)
            out.stoppingMargin = (yTrue - out.F_stop) / abs(yTrue);
            out.stopForceRatio = out.F_stop / abs(yTrue);
        end
        tLu = findLastKrUpdateStep(traj, t);
        if isfinite(tLu)
            out.F_lastUpdate = forceEval(tLu);
            out.F_used = min(out.F_stop, out.F_lastUpdate);
        end
        break;
    end
end

if ~out.isSafeStop
    if isfinite(traj.crossStep)
        out.outcome = string(traj.crossOutcome);
        out.t_stop = traj.crossStep;
        out.F_stop = forceEval(traj.crossStep);
    elseif ~out.hadValidKr
        out.outcome = "fail_no_kr";
    else
        out.outcome = "fail_never_stopped";
    end
end

tHorizon = tYieldEnd;
if out.isSafeStop && isfinite(out.t_stop)
    tHorizon = min(out.t_stop, tYieldEnd);
end

[tFu, yFu, fFu] = findFinalUpdatePrediction(traj, forceEval, tHorizon);
out.t_finalUpdate = tFu;
out.y_hat_finalUpdate = yFu;
out.F_finalUpdate = fFu;
if isfinite(yFu)
    out.finalUpdateErrorN = abs(yFu - yTrue);
    out.relativeFinalUpdateError = calcRelativeError(yFu, yTrue);
end

end

function tLu = findLastKrUpdateStep(traj, tStop)
%findLastKrUpdateStep tStop 以前で kr が最後に更新されたステップ
tLu = nan;
prevKr = nan;
for t = 1:tStop
    kr = resolveTrajectoryKrAt(traj, t);
    if ~isfinite(kr)
        continue;
    end
    if ~isfinite(prevKr) || kr ~= prevKr
        tLu = t;
        prevKr = kr;
    end
end
end

function [tLast, yLast, fLast] = findFinalUpdatePrediction(traj, forceEval, tHorizon)
%findFinalUpdatePrediction 評価上限以前で yHat が最後に更新された予測
tLast = nan;
yLast = nan;
fLast = nan;
if ~isfinite(tHorizon) || tHorizon < 1
    return;
end
tHorizon = min(max(1, round(tHorizon)), numel(forceEval));

yTol = 1e-6;  % 力スケール [N] の実質更新閾値
prevY = nan;
for t = 1:tHorizon
    if ~traj.hadValidKr(t) || ~isfinite(traj.yHat(t))
        continue;
    end
    yNow = traj.yHat(t);
    if ~isfinite(prevY) || abs(yNow - prevY) > yTol
        tLast = t;
        yLast = yNow;
        fLast = forceEval(t);
        prevY = yNow;
    end
end
end

function relErr = calcRelativeError(yHat, yTrue)
relErr = nan;
if isfinite(yHat) && isfinite(yTrue) && yTrue ~= 0
    relErr = abs(yHat - yTrue) / abs(yTrue);
end
end
