function ci = bootstrapLoocvR2Ci(y, yPred, cfg)
%bootstrapLoocvR2Ci LOOCV 予測に対する R2 の bootstrap 95% CI

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end
ci = bootstrapLoocvMetricCi(y, yPred, "r2", cfg);
end
