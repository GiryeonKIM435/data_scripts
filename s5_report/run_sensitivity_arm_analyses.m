function results = run_sensitivity_arm_analyses(cfg, opts)
%RUN_SENSITIVITY_ARM_ANALYSES Offline + sequential + contribution for one sensitivity tag

if nargin < 1 || isempty(cfg)
    error("run_sensitivity_arm_analyses:NoCfg", "cfg is required.");
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "analysisTag") || strlength(string(opts.analysisTag)) == 0
    opts.analysisTag = string(cfg.analysis.primaryAnalysisTag);
end
if ~isfield(opts, "reuseExisting")
    opts.reuseExisting = true;
end
if ~isfield(opts, "writeFigures")
    opts.writeFigures = false;
end

tag = char(string(opts.analysisTag));
cfg.cache.cohortAnalysisTag = tag;
cfg.paper.q3AnalysisTag = tag;
cfg.q7.analysisTag = tag;
cfg.analysis.primaryAnalysisTag = tag;
cfg.q7.methodTypes = "force_abs";
cfg = syncPaperKrVariant(cfg);

analysisOpts = struct( ...
    "useOutlierFilter", false, ...
    "analysisTag", tag, ...
    "reuseExisting", opts.reuseExisting, ...
    "writeFigures", opts.writeFigures);

fprintf("=== sensitivity arm [%s]: post-test ===\n", tag);
offlineResults = run_offline_evaluation(cfg, analysisOpts);
fprintf("=== sensitivity arm [%s]: sequential replay ===\n", tag);
onlineResults = run_online_evaluation(cfg, analysisOpts);
fprintf("=== sensitivity arm [%s]: additional predictors ===\n", tag);
contribResults = run_contribution_study(cfg, struct( ...
    "useOutlierFilter", false, ...
    "analysisTag", tag, ...
    "writeFigures", opts.writeFigures));

results = struct();
results.createdAt = datetime("now");
results.analysisTag = tag;
results.offline = offlineResults;
results.online = onlineResults;
results.contribution = contribResults;
end
