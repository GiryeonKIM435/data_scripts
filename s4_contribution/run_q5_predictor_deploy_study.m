function results = run_q5_predictor_deploy_study(cfg, opts)
%RUN_Q5_PREDICTOR_DEPLOY_STUDY Q5 additional-predictor models
%
% Paper mode (opts.paperPostTestOnly=true, default for repro):
%   single post-test LOOCV track only (no sequential online deploy).

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    if isfield(cfg, "q5") && isfield(cfg.q5, "useOutlierFilter")
        opts.useOutlierFilter = cfg.q5.useOutlierFilter;
    else
        opts.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
    end
end
if ~isfield(opts, "paperPostTestOnly")
    opts.paperPostTestOnly = true;
end
paperPostTestOnly = logical(opts.paperPostTestOnly);

q3AnalysisTag = resolveQ5Q3AnalysisTag(cfg, opts);
krVariant = char(string(cfg.deploy.krVariant));
if isfield(cfg, "q5") && isfield(cfg.q5, "krVariant") ...
        && strlength(string(cfg.q5.krVariant)) > 0
    krVariant = char(string(cfg.q5.krVariant));
end
cfg.q5.krVariant = krVariant;

[offlineKrKey, offlineKeySource] = resolveQ5OfflineBestKrMethodKey(cfg, opts);
if isfield(opts, "offlineKrMethodKey") && strlength(string(opts.offlineKrMethodKey)) > 0
    offlineKrKey = char(string(opts.offlineKrMethodKey));
    offlineKeySource = "opts.offlineKrMethodKey";
end
[onlineKrKey, onlineKeySource] = resolveQ5KrMethodKey(cfg, opts);
if isfield(opts, "onlineKrMethodKey") && strlength(string(opts.onlineKrMethodKey)) > 0
    onlineKrKey = char(string(opts.onlineKrMethodKey));
    onlineKeySource = "opts.onlineKrMethodKey";
end

fprintf("Q5: post-test track k = %s (%s)\n", offlineKrKey, offlineKeySource);
if ~paperPostTestOnly
    fprintf("Q5: sequential track k = %s (%s)\n", onlineKrKey, onlineKeySource);
end

cohort = loadStudyCohort(cfg, struct("useOutlierFilter", opts.useOutlierFilter));
tbl = cohort.predictorTable;

offlineKrCol = resolveDeployKrColumn(tbl, offlineKrKey, krVariant);
onlineKrCol = resolveDeployKrColumn(tbl, onlineKrKey, krVariant);

if ~ismember("d_eq", string(tbl.Properties.VariableNames))
    error("run_q5_predictor_deploy_study:MissingDeq", ...
        "predictorTable missing d_eq; re-run doPreprocess.");
end

rootOut = fullfile(cfg.out.q5, q3AnalysisTag);
if ~isfolder(rootOut)
    mkdir(rootOut);
end

offlineOut = fullfile(rootOut, "track_offline_" + offlineKrKey);
offlineTrack = runQ5SingleTrack(cfg, cohort, struct( ...
    "trackId", "offline", ...
    "krMethodKey", offlineKrKey, ...
    "krCol", offlineKrCol, ...
    "q3AnalysisTag", q3AnalysisTag, ...
    "runOnlineDeploy", false), offlineOut, opts);

onlineTrack = struct();
crossSummary = table();
if ~paperPostTestOnly
    onlineOut = fullfile(rootOut, "track_online_" + onlineKrKey);
    onlineTrack = runQ5SingleTrack(cfg, cohort, struct( ...
        "trackId", "online", ...
        "krMethodKey", onlineKrKey, ...
        "krCol", onlineKrCol, ...
        "q3AnalysisTag", q3AnalysisTag, ...
        "runOnlineDeploy", true), onlineOut, opts);
    crossSummary = buildQ5CrossTrackSummary(offlineTrack, onlineTrack, cfg, rootOut);
    if cfg.figures.enabled
        plotQ5CrossTrackDualForest(crossSummary, ...
            fullfile(rootOut, "fig_q5_cross_track_comparison.png"), cfg, ...
            struct("title", "Cross-track predictor contribution (\DeltaMAE vs M0)"));
    end
end

results = struct();
results.createdAt = datetime("now");
results.q3AnalysisTag = q3AnalysisTag;
results.krVariant = krVariant;
results.cohort = cohort;
results.offlineTrack = offlineTrack;
results.onlineTrack = onlineTrack;
results.crossSummary = crossSummary;
results.offlineKrMethodKey = char(offlineKrKey);
results.offlineKrCol = char(offlineKrCol);
results.onlineKrMethodKey = char(onlineKrKey);
results.onlineKrCol = char(onlineKrCol);
results.offlineKrKeySource = offlineKeySource;
results.onlineKrKeySource = onlineKeySource;
results.paperPostTestOnly = paperPostTestOnly;
results.outputDir = rootOut;

save(fullfile(rootOut, "q5_results.mat"), "results", "-v7");
fprintf("Q5 finished: %s\n", rootOut);
end

function tag = resolveQ5Q3AnalysisTag(cfg, opts)
if nargin >= 2 && isfield(opts, "q3AnalysisTag") && strlength(string(opts.q3AnalysisTag)) > 0
    tag = char(string(opts.q3AnalysisTag));
    return;
end
if isfield(cfg, "q5") && isfield(cfg.q5, "q3AnalysisTag") ...
        && strlength(string(cfg.q5.q3AnalysisTag)) > 0
    tag = char(string(cfg.q5.q3AnalysisTag));
    return;
end
tag = resolvePaperQ3AnalysisTag(cfg);
end
