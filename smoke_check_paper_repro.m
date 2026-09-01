% smoke_check_paper_repro.m — path resolution for paper stages (no full recompute)
repoRoot = fileparts(mfilename("fullpath"));
cd(repoRoot);
setup_paths();

required = [ ...
    "run_build_tomato_dataset", "run_estimate_noise", "run_detect_yield_and_filter", ...
    "run_fit_jeffreys_visco", "run_fit_burgers_visco", "run_estimate_kr", "run_build_master_table", ...
    "run_write_cohort_manifest", "run_prepare_jeffreys_bi_iqr15", ...
    "run_prepare_burgers_bi_iqr15", ...
    "run_prepare_jeffreys_no_iqr", "run_prepare_jeffreys_incl_visual", ...
    "run_prepare_jeffreys_harvest_day_subset", ...
    "applyJeffreysNoIqrPaths", "applyJeffreysInclVisualPaths", "applyJeffreysKrLsPaths", ...
    "applyJeffreysHarvestDayPaths", ...
    "run_sensitivity_arm_analyses", "run_sensitivity_checks_summary", ...
    "run_descriptive_report", "run_harvest_batch_summary", ...
    "run_offline_evaluation", "run_online_evaluation", ...
    "run_contribution_study", "runNestedLoocvModels", ...
    "run_yield_detection_audit", "run_jeffreys_fit_audit", ...
    "run_paper_fig_table", "run_assemble_paper_outputs", "plotCorrMatrixFigure", ...
    "PaperStudyConfig", "ensurePipelineReady", ...
    "plotOnlineMaeBioyieldPrematureHeatmaps", "summarizeKrIntervalPreYieldFeasibility"];

missing = strings(0, 1);
for i = 1:numel(required)
    name = required(i);
    if exist(name, "file") ~= 2 && exist(name, "class") ~= 8
        missing(end + 1, 1) = name; %#ok<AGROW>
    end
end

runText = fileread(fullfile(repoRoot, "RUN__paper.m"));
forbidden = ["doOfflineNested", "doOnlineNested", "doSensitivity90", ...
    "doSensitivityBurgersIqrOn", "doKrOffsetCorrelation", "doKrEarlyTrailSimilarity", ...
    "doPiForceAnalysis", "doInclVisualExcludedSensitivity", ...
    "doAssemble", "doYieldAudit", "doJeffreysAudit", "doSequentialReplayExample", ...
    "doContribution", "doBurgersAudit"];
foundForbidden = strings(0, 1);
for i = 1:numel(forbidden)
    tok = forbidden(i);
    if contains(runText, tok)
        foundForbidden(end + 1, 1) = tok; %#ok<AGROW>
    end
end

neededFlags = ["doLoad", "doEstimate", "doPreprocess", "doDescriptive", ...
    "doPostTest", "doSequentialReplay", "doAdditionalPredictors", "doFigTable", ...
    "doSensitivityNoIqr", "doSensitivityInclVisual", "doSensitivityKrLs", ...
    "doSensitivityHarvestDay", "doSensitivitySummary"];
missingFlags = strings(0, 1);
for i = 1:numel(neededFlags)
    if ~contains(runText, neededFlags(i))
        missingFlags(end + 1, 1) = neededFlags(i); %#ok<AGROW>
    end
end

fprintf("smoke: required functions missing = %d\n", numel(missing));
if ~isempty(missing)
    disp(missing);
end
fprintf("smoke: forbidden legacy flags still in RUN__paper = %d\n", numel(foundForbidden));
if ~isempty(foundForbidden)
    disp(foundForbidden);
end
fprintf("smoke: paper flags missing = %d\n", numel(missingFlags));
if ~isempty(missingFlags)
    disp(missingFlags);
end

ok = isempty(missing) && isempty(foundForbidden) && isempty(missingFlags);
if ok
    fprintf("SMOKE_OK\n");
else
    fprintf("SMOKE_FAIL\n");
    exit(1);
end
exit(0);
