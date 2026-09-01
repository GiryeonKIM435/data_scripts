function traj = applyDeployPiecewiseCalibToTrajectory(krPath, yTrue, aLow, bLow, aHigh, bHigh, switchForceN)
%applyDeployPiecewiseCalibToTrajectory レジーム別 LOO (a,b) を kr 軌跡に適用

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

if nargin < 7 || isempty(switchForceN)
    if isfield(krPath, "switchForceN")
        switchForceN = krPath.switchForceN;
    else
        switchForceN = nan;
    end
end

everKr = false;
for t = 1:T
    if isfinite(krPath.crossStep) && t >= krPath.crossStep
        break;
    end
    krAtT = resolveTrajectoryKrAt(krPath, t);
    forceAbs = traj.forceAbs(t);
    if isfinite(forceAbs) && forceAbs < switchForceN
        a = aLow;
        b = bLow;
    else
        a = aHigh;
        b = bHigh;
    end
    if isfinite(krAtT)
        everKr = true;
    end
    if isfinite(krAtT) && isfinite(a) && isfinite(b)
        traj.yHat(t) = a * krAtT + b;
    end
    traj.hadValidKr(t) = everKr && isfinite(traj.yHat(t));
end

end
