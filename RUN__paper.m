%% =====================================================================
%  RUN__paper : reproduce the manuscript analyses
%
%  Suggested order:
%    doLoad -> doEstimate -> doPreprocess
%    -> doDescriptive (4.1) -> doPostTest (4.2)
%    -> doSequentialReplay (4.3) -> doAdditionalPredictors (4.4)
%    -> doFigTable
%    -> optional single-factor sensitivity (IQR / visual / LS-k / harvest day)
%
%  Jeffreys multi-start identification is stochastic. To match the
%  manuscript numbers, keep useShippedJeffreysCohort=true (default) so
%  the shipped *_bi_iqr15.mat products are loaded. See README.md.
%  =====================================================================

doLoad = false;                    % raw Excel+CSV -> tomato_dataset.mat
doEstimate = false;                % noise / bioyield / Jeffreys / k
doPreprocess = false;              % master table / cohort (non-IQR pipeline)
doDescriptive = false;             % Results 4.1
doPostTest = false;                % Results 4.2
doSequentialReplay = false;        % Results 4.3
doAdditionalPredictors = false;    % Results 4.4
doFigTable = false;                % paper figures/tables

% Single-factor sensitivity (each vs manuscript primary; no combinations)
doSensitivityNoIqr = true;        % Jeffreys IQR reject off
doSensitivityInclVisual = true;   % primary complete + visual IDs 8,71 (no re-IQR; target n=89)
doSensitivityKrLs = true;         % same cohort; stiffness k via LS (not chord)
doSensitivityHarvestDay = true;   % Apr-23-only and Apr-29-only subsets
doSensitivitySummary = true;      % write sensitivity_vs_primary.csv

%% ========== Stages to run ==========
doLoad = true;
doEstimate = true;
doPreprocess = true;
doDescriptive = true;
doPostTest = true;
doSequentialReplay = true;
doAdditionalPredictors = true;
doFigTable = true;

%% ========== Shared parameters ==========
% Output / cache folder tag under sec4_* and shared_cache.
% Paper-matching default: "jeffreys_bi_iqr15"
primaryAnalysisTag = "jeffreys_bi_iqr15";
% true  -> load shipped Jeffreys IQR mats (manuscript numbers; recommended)
% false -> allow regenerating via run_prepare_jeffreys_bi_iqr15 (stochastic)
useShippedJeffreysCohort = true;
reuseExistingResults = true;   % reuse existing 4.2/4.3 .mat when present
skipIfExists = true;           % skip prepare products that already exist
forceRecompute = false;        % force prepare recompute (overrides skip)

%% ========== Execution ==========
setup_paths();

%% --- s1: prepare ---
if doLoad || doEstimate || doPreprocess
    prepOpts = defaultRunOptions();
    prepOpts.skipIfExists = skipIfExists;
    prepOpts.forceRecompute = forceRecompute;
    prepOpts.analyze.useOutlierFilter = false;
    prepOpts.runStages.doEstimate = doEstimate;
    prepOpts.saveFigures = false;

    if doLoad
        fprintf("=== s1: load (raw -> tomato_dataset) ===\n");
        run_build_tomato_dataset(prepOpts);
    end
    if doEstimate
        fprintf("=== s1: estimate (noise / bioyield / Jeffreys / k) ===\n");
        run_estimate_noise(prepOpts);
        run_detect_yield_and_filter(prepOpts);
        run_fit_jeffreys_visco(prepOpts);
        run_estimate_kr(prepOpts);
        run_extract_creep_waveform(prepOpts);
        run_summarize_estimate_params(prepOpts);
    end
    if doPreprocess
        fprintf("=== s1: preprocess (master table / cohort) ===\n");
        run_build_master_table(prepOpts);
        run_diagnose_outliers(prepOpts);
        run_write_cohort_manifest(prepOpts);
        run_summarize_cohort_params(prepOpts);
        if ~useShippedJeffreysCohort
            fprintf("=== s1: regenerate Jeffreys IQR cohort (stochastic) ===\n");
            warning("RUN__paper:StochasticJeffreysCohort", ...
                "Regenerating Jeffreys IQR cohort. Multi-start uses RNG; complete-set / offline metrics may differ from the manuscript. Set useShippedJeffreysCohort=true to load shipped mats.");
            cfgPrep = PaperStudyConfig();
            run_prepare_jeffreys_bi_iqr15(cfgPrep, struct( ...
                "skipIfExists", skipIfExists, ...
                "forceRecompute", forceRecompute));
        end
    end
end

%% --- Shared analysis setup ---
needAnalysis = doDescriptive || doPostTest || doSequentialReplay ...
    || doAdditionalPredictors || doFigTable ...
    || doSensitivityNoIqr || doSensitivityInclVisual || doSensitivityKrLs ...
    || doSensitivityHarvestDay || doSensitivitySummary;
if needAnalysis
    cfgPrep = PaperStudyConfig();
    requiredCohort = [ ...
        string(cfgPrep.paths.tomatoWithFitBiIqr15); ...
        string(cfgPrep.paths.jeffreysFitResultsBiIqr15); ...
        string(cfgPrep.paths.masterTableBiIqr15); ...
        string(cfgPrep.paths.cohortManifestBiIqr15)];
    missingCohort = requiredCohort(~isfile(requiredCohort));

    if useShippedJeffreysCohort
        if ~isempty(missingCohort)
            error("RUN__paper:MissingManuscriptCohort", ...
                "Manuscript Jeffreys IQR mats missing under outputs/prepare/:\n  %s\nRestore the shipped *_bi_iqr15.mat products, or set useShippedJeffreysCohort=false to regenerate (stochastic).", ...
                strjoin(missingCohort, newline));
        end
        fprintf("Using shipped Jeffreys IQR cohort mats (paper-matching)\n");
    else
        if ~isempty(missingCohort) || forceRecompute
            fprintf("=== ensure Jeffreys IQR cohort (regenerate; stochastic) ===\n");
            prepIqrOpts = struct( ...
                "skipIfExists", skipIfExists && ~forceRecompute, ...
                "forceRecompute", forceRecompute);
            run_prepare_jeffreys_bi_iqr15(cfgPrep, prepIqrOpts);
        end
    end

    cfg = ensurePipelineReady();
    cfg.deploy.krVariant = "chord";
    cfg = syncPaperKrVariant(cfg);
    cfg.cache.cohortAnalysisTag = primaryAnalysisTag;
    cfg.paper.q3AnalysisTag = primaryAnalysisTag;
    cfg.analysis.primaryAnalysisTag = primaryAnalysisTag;
    cfg.q7.methodTypes = "force_abs";

    poolInfo = ensurePaperStudyParallelPool(cfg);
    if poolInfo.active
        fprintf("Parallel pool: %s, %d workers\n", poolInfo.poolType, poolInfo.nWorkers);
    end

    analysisOpts = struct( ...
        "useOutlierFilter", false, ...
        "analysisTag", primaryAnalysisTag, ...
        "reuseExisting", reuseExistingResults, ...
        "writeFigures", false);
end

%% --- Results 4.1 ---
if doDescriptive
    fprintf("=== 4.1: descriptive statistics ===\n");
    descriptiveResults = run_descriptive_report(cfg, struct( ...
        "useOutlierFilter", false, ...
        "writeFigures", false));
    fprintf("=== 4.1b: harvest batch summary ===\n");
    harvestBatchResults = run_harvest_batch_summary(cfg, struct( ...
        "useOutlierFilter", false, ...
        "krMethodKey", "force_s00_w30"));
end

%% --- Results 4.2 ---
if doPostTest
    fprintf("=== 4.2: post-test evaluation ===\n");
    postTestResults = run_offline_evaluation(cfg, analysisOpts);
end

%% --- Results 4.3 ---
if doSequentialReplay
    fprintf("=== 4.3: sequential replay ===\n");
    sequentialResults = run_online_evaluation(cfg, analysisOpts);
end

%% --- Results 4.4 ---
if doAdditionalPredictors
    fprintf("=== 4.4: additional predictors ===\n");
    additionalPredictorResults = run_contribution_study(cfg, struct( ...
        "useOutlierFilter", false, ...
        "writeFigures", false));
end

%% --- Paper figures / tables ---
if doFigTable
    fprintf("=== doFigTable: paper figures/tables ===\n");
    figOpts = analysisOpts;
    figOpts.writeFigures = true;
    figOpts.reuseExisting = true;
    paperFigTable = run_paper_fig_table(cfg, figOpts);
end

%% --- Sensitivity: single-factor arms vs primary ---
sensPrepOpts = struct( ...
    "skipIfExists", skipIfExists, ...
    "forceRecompute", forceRecompute);
sensRunOpts = struct( ...
    "reuseExisting", reuseExistingResults, ...
    "writeFigures", false);

if doSensitivityNoIqr
    fprintf("=== sensitivity: Jeffreys IQR off (single factor) ===\n");
    run_prepare_jeffreys_no_iqr(cfg, sensPrepOpts);
    sensCfg = applyJeffreysNoIqrPaths(PaperStudyConfig());
    sensCfg.deploy.krVariant = "chord";
    sensCfg = syncPaperKrVariant(sensCfg);
    sensCfg.q7.methodTypes = "force_abs";
    sensitivityNoIqr = run_sensitivity_arm_analyses(sensCfg, sensRunOpts);
end

if doSensitivityInclVisual
    fprintf("=== sensitivity: include visual-excluded IDs 8,71 (single factor; no re-IQR) ===\n");
    run_prepare_jeffreys_incl_visual(cfg, sensPrepOpts);
    sensCfg = applyJeffreysInclVisualPaths(PaperStudyConfig());
    sensCfg.deploy.krVariant = "chord";
    sensCfg = syncPaperKrVariant(sensCfg);
    sensCfg.q7.methodTypes = "force_abs";
    sensitivityInclVisual = run_sensitivity_arm_analyses(sensCfg, sensRunOpts);
end

if doSensitivityKrLs
    fprintf("=== sensitivity: stiffness k via LS (single factor; same primary cohort) ===\n");
    sensCfg = applyJeffreysKrLsPaths(PaperStudyConfig());
    sensCfg.q7.methodTypes = "force_abs";
    sensitivityKrLs = run_sensitivity_arm_analyses(sensCfg, sensRunOpts);
end

if doSensitivityHarvestDay
    fprintf("=== sensitivity: harvest-day subsets (single factor each) ===\n");
    prepDay = sensPrepOpts;
    prepDay.day = "0423";
    run_prepare_jeffreys_harvest_day_subset(cfg, prepDay);
    prepDay.day = "0429";
    run_prepare_jeffreys_harvest_day_subset(cfg, prepDay);

    sensCfg = applyJeffreysHarvestDayPaths(PaperStudyConfig(), "0423");
    sensCfg.deploy.krVariant = "chord";
    sensCfg = syncPaperKrVariant(sensCfg);
    sensCfg.q7.methodTypes = "force_abs";
    sensitivityHarvest0423 = run_sensitivity_arm_analyses(sensCfg, sensRunOpts);

    sensCfg = applyJeffreysHarvestDayPaths(PaperStudyConfig(), "0429");
    sensCfg.deploy.krVariant = "chord";
    sensCfg = syncPaperKrVariant(sensCfg);
    sensCfg.q7.methodTypes = "force_abs";
    sensitivityHarvest0429 = run_sensitivity_arm_analyses(sensCfg, sensRunOpts);
end

if doSensitivitySummary
    fprintf("=== sensitivity summary vs primary ===\n");
    sensitivitySummary = run_sensitivity_checks_summary(cfg);
end

fprintf("RUN__paper finished. Outputs: %s\n", ...
    fullfile(fileparts(mfilename("fullpath")), "outputs"));
