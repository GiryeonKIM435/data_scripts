function traj = streamDeployTrajectory(ctx, yTrue, a, b, methodDef, fitCfg, krVariant)
%streamDeployTrajectory sec 昇順ストリーミング軌跡（増分 kr、α 非依存）

if nargin < 7
    krVariant = "chord";
end

sampleOpts = struct("krVariant", krVariant);
krPath = streamDeployKrPath(ctx, yTrue, methodDef, fitCfg, sampleOpts);
traj = applyDeployCalibToTrajectory(krPath, yTrue, a, b);

end
