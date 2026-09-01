function out = runStreamingDeployFold(ctx, yTrue, a, b, methodDef, alpha, fitCfg)
%runStreamingDeployFold 1 fold: trajectory + alpha 評価（後方互換ラッパー）

traj = streamDeployTrajectory(ctx, yTrue, a, b, methodDef, fitCfg);
out = evalStopAlphas(traj, alpha, yTrue);

end
