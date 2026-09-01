function traj = applyDeployCalibToTrajectory(krPath, yTrue, a, b)
%applyDeployCalibToTrajectory kr 軌跡に LOO キャリブ (a,b) を適用

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

usePrecomputedYHat = isfield(krPath, "yHat") && isvector(krPath.yHat) ...
    && numel(krPath.yHat) >= T;

everKr = false;
for t = 1:T
    if isfinite(krPath.crossStep) && t >= krPath.crossStep
        break;
    end
    krAtT = resolveTrajectoryKrAt(krPath, t);
    if isfinite(krAtT)
        everKr = true;
    end
    if usePrecomputedYHat && isfinite(krPath.yHat(t))
        traj.yHat(t) = krPath.yHat(t);
    elseif isfinite(krAtT) && isfinite(a) && isfinite(b)
        traj.yHat(t) = a * krAtT + b;
    end
    traj.hadValidKr(t) = everKr && isfinite(traj.yHat(t));
end

end
