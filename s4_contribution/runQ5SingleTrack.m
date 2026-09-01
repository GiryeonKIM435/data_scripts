function trackResult = runQ5SingleTrack(cfg, cohort, trackSpec, outDir, opts)
%runQ5SingleTrack Q5 単一トラック（diagnostics → offline → optional online → stats → figures）

if nargin < 5
    opts = struct();
end
if ~isfolder(outDir)
    mkdir(outDir);
end

krMethodKey = string(trackSpec.krMethodKey);
krCol = string(trackSpec.krCol);
q3AnalysisTag = trackSpec.q3AnalysisTag;
runOnlineDeploy = isfield(trackSpec, "runOnlineDeploy") && trackSpec.runOnlineDeploy;

fprintf("Q5 track [%s]: kr=%s (%s), online=%d\n", ...
    trackSpec.trackId, krMethodKey, krCol, runOnlineDeploy);

modelCases = buildQ5ModelCaseDefs(cfg, krCol);

fprintf("Q5 track [%s]: exploratory diagnostics (n=%d)...\n", trackSpec.trackId, cohort.n);
diag = runQ5ExploratoryDiagnostics(cohort, modelCases, cfg, outDir, krCol);

fprintf("Q5 track [%s]: offline LOOCV regression...\n", trackSpec.trackId);
offline = runQ5OfflineRegression(cohort, diag.caseReduced, cfg, outDir, krCol);

online = struct("summaryTable", table(), "perSampleTable", table());
if runOnlineDeploy
    fprintf("Q5 track [%s]: online deploy simulation...\n", trackSpec.trackId);
    online = runQ5OnlineDeploy(cfg, cohort, diag.caseReduced, krMethodKey, krCol, ...
        q3AnalysisTag, outDir);
end

fprintf("Q5 track [%s]: model comparison stats...\n", trackSpec.trackId);
caseStats = runQ5ModelComparison(offline, online, cfg, outDir);

if cfg.figures.enabled
    fprintf("Q5 track [%s]: figures...\n", trackSpec.trackId);
    plotQ5Figures(diag, offline, online, cfg, outDir, krCol);
end

trackResult = struct();
trackResult.trackId = char(trackSpec.trackId);
trackResult.krMethodKey = char(krMethodKey);
trackResult.krCol = char(krCol);
trackResult.runOnlineDeploy = runOnlineDeploy;
trackResult.modelCases = modelCases;
trackResult.diagnostics = diag;
trackResult.offline = offline;
trackResult.online = online;
trackResult.caseStats = caseStats;
trackResult.outputDir = outDir;

end
