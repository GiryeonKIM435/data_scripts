function traj = applyMultivariateDeployCalibToTrajectory(krPath, yTrue, calib, foldIdx, staticRow)
%applyMultivariateDeployCalibToTrajectory 多変量 LOO キャリブで y_hat 軌跡を構築

traj = krPath;
traj.yTrue = double(yTrue);
T = krPath.nSteps;
traj.yHat = nan(T, 1);
traj.hadValidKr = false(T, 1);
if isfield(krPath, "forceAbs")
    traj.forceAbs = krPath.forceAbs;
elseif isfield(krPath, "forceOffsetN") && isfinite(krPath.forceOffsetN)
    traj.forceAbs = krPath.force + krPath.forceOffsetN;
else
    traj.forceAbs = krPath.force;
end

predictors = string(calib.predictors(:));
staticRow = double(staticRow(:).');
krCol = predictors(1);
if isfield(calib, "krCol") && strlength(string(calib.krCol)) > 0
    krCol = string(calib.krCol);
end
krIdx = find(predictors == krCol, 1);
if isempty(krIdx)
    error("applyMultivariateDeployCalibToTrajectory:NoKrCol", ...
        "predictors に kr 列 %s がありません。", krCol);
end

muX = calib.muX(foldIdx, :);
sigX = calib.sigX(foldIdx, :);
sigX(sigX == 0) = 1;
muY = calib.muY(foldIdx);
sigY = calib.sigY(foldIdx);
if sigY == 0
    sigY = 1;
end
b0 = calib.b0(foldIdx);
beta = calib.beta(foldIdx, :);

staticIdx = setdiff(1:numel(predictors), krIdx);
if numel(staticIdx) ~= numel(staticRow)
    error("applyMultivariateDeployCalibToTrajectory:StaticSize", ...
        "static predictor 数が一致しません。");
end

everKr = false;
for t = 1:T
    if isfield(krPath, "crossStep") && isfinite(krPath.crossStep) && t >= krPath.crossStep
        break;
    end
    krAtT = resolveTrajectoryKrAt(krPath, t);
    if ~isfinite(krAtT)
        continue;
    end
    Xrow = nan(1, numel(predictors));
    Xrow(krIdx) = krAtT;
    Xrow(staticIdx) = staticRow;
    if any(~isfinite(Xrow))
        continue;
    end
    Z = (Xrow - muX) ./ sigX;
    yHatZ = b0 + Z * beta(:);
    traj.yHat(t) = yHatZ * sigY + muY;
    everKr = true;
    traj.hadValidKr(t) = isfinite(traj.yHat(t));
end

end
