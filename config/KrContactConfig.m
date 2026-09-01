function cfg = KrContactConfig()
%KrContactConfig kr 接触開始（正傾きアンカー + 2σ スラック逆遡り）検出パラメータ

cfg = struct();
cfg.method = "slope_backtrack_slack_run";
cfg.slackSigmaMult = 2;
cfg.minSlackRun = 5;
cfg.obviousSigmaMult = 7;
cfg.positiveSigmaMult = 4;
cfg.minObviousRun = 7;
cfg.baselineFrac = 0.05;
cfg.baselineMinPoints = 8;
cfg.zeroAtContact = true;
cfg.minDefStepMm = 1e-4;

end
