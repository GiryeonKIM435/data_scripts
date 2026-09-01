function results = run_paper_fig_table(cfg, opts)
%RUN_PAPER_FIG_TABLE Opportunistic paper figures/tables (doFigTable)
%
% Regenerates Methods/Results figures from existing compute products when
% available, then assembles paper_figures / paper_tables. Missing inputs are
% skipped (does not require all stages to have finished).

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = false;
end
if ~isfield(opts, "analysisTag") || strlength(string(opts.analysisTag)) == 0
    opts.analysisTag = resolvePaperQ3AnalysisTag(cfg);
end
opts.writeFigures = true;
opts.reuseExisting = true;
if isfield(cfg, "figures")
    cfg.figures.enabled = true;
end

analysisTag = string(opts.analysisTag);
gammaTag = "gamma_" + strrep(sprintf("%.1f", cfg.q7.gammaValues(1)), ".", "p");
sec42 = fullfile(cfg.out.q1, analysisTag);
sec43 = fullfile(cfg.out.q7, analysisTag, gammaTag);
sec44 = fullfile(cfg.out.q5, analysisTag);
q1Mat = fullfile(sec42, "kr_benchmark_results.mat");
q7Mat = fullfile(cfg.out.q7, analysisTag, "q7_design_alpha_deploy_results.mat");
q5Mat = fullfile(sec44, "q5_results.mat");
corrMat = fullfile(sec44, "predictor_correlation_results.mat");

results = struct();
results.createdAt = datetime("now");
results.skipped = strings(0, 1);
results.ran = strings(0, 1);

%% Methods audits
try
    if prepareReadyForAudits(cfg)
        fprintf("doFigTable: Methods bioyield audit\n");
        results.yieldAudit = run_yield_detection_audit(cfg, struct());
        results.ran(end + 1, 1) = "methods_bioyield";
        try
            cohortFeas = loadStudyCohort(cfg, struct( ...
                "useOutlierFilter", opts.useOutlierFilter));
            results.feasTable = summarizeKrIntervalPreYieldFeasibility(cfg, cohortFeas);
            results.ran(end + 1, 1) = "methods_preyield_feasibility";
        catch ME
            warning("run_paper_fig_table:Feasibility", "%s", ME.message);
            results.skipped(end + 1, 1) = "methods_preyield_feasibility";
        end
    else
        fprintf("doFigTable: skip Methods bioyield (prepare products missing)\n");
        results.skipped(end + 1, 1) = "methods_bioyield";
    end
catch ME
    warning("run_paper_fig_table:YieldAudit", "%s", ME.message);
    results.skipped(end + 1, 1) = "methods_bioyield";
end

try
    if prepareReadyForJeffreys(cfg)
        fprintf("doFigTable: Methods Jeffreys audit\n");
        results.jeffreysAudit = run_jeffreys_fit_audit(cfg, struct());
        results.ran(end + 1, 1) = "methods_jeffreys";
    else
        fprintf("doFigTable: skip Methods Jeffreys (fit products missing)\n");
        results.skipped(end + 1, 1) = "methods_jeffreys";
    end
catch ME
    warning("run_paper_fig_table:JeffreysAudit", "%s", ME.message);
    results.skipped(end + 1, 1) = "methods_jeffreys";
end

%% 4.1 descriptive tables (+ preview figures)
try
    if cohortReady(cfg, opts)
        fprintf("doFigTable: Results 4.1 descriptive tables/previews\n");
        results.descriptive = run_descriptive_report(cfg, struct( ...
            "useOutlierFilter", opts.useOutlierFilter, ...
            "writeFigures", true));
        results.ran(end + 1, 1) = "results_4_1";
    else
        fprintf("doFigTable: skip 4.1 (cohort missing)\n");
        results.skipped(end + 1, 1) = "results_4_1";
    end
catch ME
    warning("run_paper_fig_table:Descriptive", "%s", ME.message);
    results.skipped(end + 1, 1) = "results_4_1";
end

%% 4.2 post-test figures from saved LOOCV
postTestResults = [];
try
    if isfile(q1Mat)
        fprintf("doFigTable: Results 4.2 post-test figures\n");
        postTestResults = run_offline_evaluation(cfg, opts);
        results.postTest = postTestResults;
        results.ran(end + 1, 1) = "results_4_2";
    else
        fprintf("doFigTable: skip 4.2 figures (%s missing)\n", q1Mat);
        results.skipped(end + 1, 1) = "results_4_2";
    end
catch ME
    warning("run_paper_fig_table:PostTest", "%s", ME.message);
    results.skipped(end + 1, 1) = "results_4_2";
end

%% 4.3 sequential-replay figures from saved Q7
sequentialResults = [];
try
    if isfile(q7Mat)
        fprintf("doFigTable: Results 4.3 sequential-replay figures\n");
        sequentialResults = run_online_evaluation(cfg, opts);
        results.sequential = sequentialResults;
        results.ran(end + 1, 1) = "results_4_3";
    else
        fprintf("doFigTable: skip 4.3 figures (%s missing)\n", q7Mat);
        results.skipped(end + 1, 1) = "results_4_3";
    end
catch ME
    warning("run_paper_fig_table:Sequential", "%s", ME.message);
    results.skipped(end + 1, 1) = "results_4_3";
end

%% Shared MAE clim when both 4.2 and 4.3 products exist
try
    if ~isempty(postTestResults) && ~isempty(sequentialResults) ...
            && isfield(postTestResults, "summaryTable") ...
            && isfield(sequentialResults, "designSummary")
        sharedMaeClim = computeGlobalMaeHeatmapClim( ...
            postTestResults.summaryTable, sequentialResults.designSummary, cfg);
        fprintf("doFigTable: redraw post-test MAE with shared clim [%.3f, %.3f]\n", ...
            sharedMaeClim(1), sharedMaeClim(2));
        pairs = [];
        if isfield(postTestResults, "pairByType")
            pairs = postTestResults.pairByType;
        elseif isfield(postTestResults, "pairTable")
            pairs = postTestResults.pairTable;
        end
        plotOfflineMaeR2Heatmaps(postTestResults.summaryTable, pairs, ...
            postTestResults.outputDir, cfg, sharedMaeClim);
        results.ran(end + 1, 1) = "shared_mae_clim";
    end
catch ME
    warning("run_paper_fig_table:SharedClim", "%s", ME.message);
    results.skipped(end + 1, 1) = "shared_mae_clim";
end

%% 4.4 figures from saved Q5 / correlation mats (post-test track only)
try
    if isfile(q5Mat)
        fprintf("doFigTable: Results 4.4 post-test LOOCV scatter\n");
        s = load(q5Mat, "results");
        q5 = s.results;
        if isfield(q5, "offlineTrack") && ~isempty(q5.offlineTrack)
            ot = q5.offlineTrack;
            onlineEmpty = struct("summaryTable", table(), "perSampleTable", table());
            if isfield(ot, "online") && ~isempty(ot.online)
                onlineEmpty = ot.online;
            end
            plotQ5Figures(ot.diagnostics, ot.offline, onlineEmpty, cfg, ...
                ot.outputDir, string(ot.krCol));
        end
        results.ran(end + 1, 1) = "results_4_4_q5";
    else
        fprintf("doFigTable: skip 4.4 Q5 figures (%s missing)\n", q5Mat);
        results.skipped(end + 1, 1) = "results_4_4_q5";
    end
catch ME
    warning("run_paper_fig_table:Q5Figures", "%s", ME.message);
    results.skipped(end + 1, 1) = "results_4_4_q5";
end

try
    if isfile(corrMat)
        fprintf("doFigTable: Results 4.4 Spearman matrix + table preview\n");
        s = load(corrMat, "results");
        corrRes = s.results;
        if isfield(corrRes, "spearmanMatrix") && isfield(corrRes, "figTickLabels")
            plotCorrMatrixFigure(corrRes.spearmanMatrix, corrRes.figTickLabels, ...
                cfg, fullfile(sec44, "fig4_4_spearman_corr_matrix.png"), "Spearman $\rho$");
        end
        if isfield(corrRes, "paperTable") && ~isempty(corrRes.paperTable)
            exportPaperTableBundle(corrRes.paperTable, ...
                fullfile(sec44, "table4_4_predictor_correlation"), ...
                sprintf("Correlation with bioyield force (n=%d)", corrRes.n), cfg);
        end
        results.ran(end + 1, 1) = "results_4_4_corr";
    else
        fprintf("doFigTable: skip 4.4 correlation figures (%s missing)\n", corrMat);
        results.skipped(end + 1, 1) = "results_4_4_corr";
    end
catch ME
    warning("run_paper_fig_table:CorrFigures", "%s", ME.message);
    results.skipped(end + 1, 1) = "results_4_4_corr";
end

%% Assemble whatever exists
fprintf("doFigTable: assemble paper_figures / paper_tables\n");
results.manifest = run_assemble_paper_outputs(cfg);
results.ran(end + 1, 1) = "assemble";

fprintf("doFigTable done: ran=%d skipped=%d\n", numel(results.ran), numel(results.skipped));
end

function tf = prepareReadyForAudits(cfg)
tf = false;
if isfield(cfg, "paths") && isfield(cfg.paths, "noiseProfile") ...
        && isfile(cfg.paths.noiseProfile)
    tf = true;
    return;
end
cand = fullfile(cfg.studyRoot, "outputs", "prepare", "02_estimate", "noise_profile.mat");
tf = isfile(cand);
end

function tf = prepareReadyForJeffreys(cfg)
tf = false;
if isfield(cfg, "paths") && isfield(cfg.paths, "tomatoWithFit") ...
        && strlength(string(cfg.paths.tomatoWithFit)) > 0 ...
        && isfile(cfg.paths.tomatoWithFit)
    tf = true;
    return;
end
cand = fullfile(cfg.studyRoot, "outputs", "prepare", "02_estimate", "tomato_with_fit.mat");
tf = isfile(cand);
end

function tf = cohortReady(cfg, opts)
try
    loadStudyCohort(cfg, struct("useOutlierFilter", opts.useOutlierFilter));
    tf = true;
catch
    tf = false;
end
end
