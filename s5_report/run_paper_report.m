function results = run_paper_report(cfg, opts)
%RUN_PAPER_REPORT Descriptive tables and overview figures for Results 4.1
if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end

if isfield(cfg, "analysis") && isfield(cfg.analysis, "excludeKrMethodTypes") ...
        && ~isempty(cfg.analysis.excludeKrMethodTypes)
    cfg = applyKrMethodExclusions(cfg, cfg.analysis.excludeKrMethodTypes);
end

paperTables = cfg.out.paperTables;
paperFigures = cfg.out.paperFigures;
for d = {cfg.out.q0, paperTables, paperFigures}
    if ~isfolder(d{1})
        mkdir(d{1});
    end
end

fprintf("Q0 paper report: コホ�Eト読込 (MAD on)...\n");
cohort = loadStudyCohort(cfg, struct("useOutlierFilter", true));
fprintf("Q0 paper report: n=%d\n", cohort.n);

results = struct();
results.createdAt = datetime("now");
results.cohort = cohort;
results.outputDir = cfg.out.q0;
results.paperTables = paperTables;
results.paperFigures = paperFigures;

q1Tag = cfg.cache.cohortAnalysisTag;
if ~isfield(cfg, "cache") || ~isfield(cfg.cache, "cohortAnalysisTag")
    q1Tag = "burgers_iqr2";
end
q1SummaryEarly = loadQ1SummaryTable(cfg, q1Tag);
exampleKey = resolvePaperExampleKrKey(cfg, q1SummaryEarly);
if strlength(exampleKey) > 0
    cfg.paper.offlineKrMethodKey = exampleKey;
    cfg.paper.exampleMethodKey = exampleKey;
    cfg.paper.exampleMethodKeysByType.force_abs = exampleKey;
    fprintf("Q0: 論文例示方弁E= %s\n", exampleKey);
end

fprintf("Q0: Table 1 試料記述統訁E..\n");
results.table1 = buildTable1SampleDescriptives(cohort, cfg, paperTables);

fprintf("Q0: Table 2 offline kr モチE�� + fig2...\n");
results.table2 = buildTable2OfflineKrModel(cohort, cfg, paperTables);

fprintf("Q0: Fig 2c online deploy scatter...\n");
q3Tag = resolvePaperQ3AnalysisTag(cfg);
q3Dir = fullfile(cfg.out.q3, q3Tag);
q3DeployForFig = struct();
q3Path = fullfile(q3Dir, "streaming_deploy_results.mat");
if isfile(q3Path)
    sq3 = load(q3Path, "results");
    q3DeployForFig = sq3.results;
else
    perCsv = fullfile(q3Dir, "streaming_deploy_per_sample.csv");
    if isfile(perCsv)
        q3DeployForFig.perSampleTable = readtable(perCsv);
    end
end
results.fig2c = plotQ3OnlineStopYieldScatter(cfg, q3DeployForFig, paperFigures);

if isfield(cfg, "paper") && isfield(cfg.paper, "doFig4AllSamples") && cfg.paper.doFig4AllSamples
    fig4OutDir = cfg.out.paperFig4All;
    if ~isfolder(fig4OutDir)
        mkdir(fig4OutDir);
    end
    fprintf("Q0: Fig 4 全試料デプロイ実施侁EↁE%s\n", fig4OutDir);
    results.fig4All = plotQ3DeployExampleCaseAllSamples(cfg, cohort, fig4OutDir);
end

q3Tag = resolvePaperQ3AnalysisTag(cfg);
q3Dir = fullfile(cfg.out.q3, q3Tag);
q3Path = fullfile(q3Dir, "streaming_deploy_results.mat");
if isfile(q3Path)
    sq3 = load(q3Path, "results");
    resultsQ3 = sq3.results;
else
    csvPath = fullfile(q3Dir, "streaming_deploy_summary.csv");
    if ~isfile(csvPath)
        error("run_paper_report:NoQ3", ...
            "Q3 結果がありません: %s また�E %s", q3Path, csvPath);
    end
    fprintf("Q0: Q3 MAT なし、summary CSV から読込 (%s)\n", csvPath);
    resultsQ3 = struct();
    resultsQ3.summaryTable = readtable(csvPath);
    resultsQ3.alphaValues = cfg.deploy.alphaValues(:);
    resultsQ3.primaryAlpha = cfg.deploy.primaryAlpha;
    resultsQ3.analysisTag = q3Tag;
end
[resultsQ3.summaryTable, ~] = filterKrSummaryToRegistry(resultsQ3.summaryTable, cfg, "Q3");
results.q3Deploy = resultsQ3;

fprintf("Q0: Fig 5 Q3 チE�Eロイ結果ヒ�Eト�EチE�E...\n");
alphaValues = cfg.deploy.alphaValues(:);
if isfield(resultsQ3, "alphaValues")
    alphaValues = resultsQ3.alphaValues(:);
end
q1Tag = cfg.cache.cohortAnalysisTag;
if ~isfield(cfg, "cache") || ~isfield(cfg.cache, "cohortAnalysisTag")
    q1Tag = "burgers_iqr2";
end
q1Summary = loadQ1SummaryTable(cfg, q1Tag);
[q1Summary, ~] = filterKrSummaryToRegistry(q1Summary, cfg, "Q1");
q1PairTable = loadQ1PairTable(cfg, q1Tag);
q3PairTable = loadQ3PairTable(cfg, q3Tag);
perCsv = fullfile(q3Dir, "streaming_deploy_per_sample.csv");
if isfile(perCsv)
    perSample = readtable(perCsv);
    resultsQ3.summaryTable = augmentStreamingDeploySummaryWithStopR2( ...
        resultsQ3.summaryTable, perSample);
end
globalMaeClim = computeGlobalMaeHeatmapClim(q1Summary, resultsQ3.summaryTable, cfg);
globalRelErrorClim = computeGlobalRelErrorHeatmapClim(q1Summary, resultsQ3.summaryTable, cfg);
globalStopR2Clim = computeGlobalStopR2HeatmapClim(resultsQ3.summaryTable, cfg);
if ~isempty(q1Summary)
    fprintf("Q0: Q1 MAE / rel-error ヒ�Eト�EチE�E再描画�E��E朁Eclim�E�E..\n");
    plotKrMethodHeatmaps(q1Summary, paperFigures, cfg, struct( ...
        "figPrefix", "fig2", ...
        "globalMaeClim", globalMaeClim, ...
        "globalRelErrorClim", globalRelErrorClim, ...
        "krVariant", cfg.deploy.krVariant, ...
        "pairTable", q1PairTable));
end
plotStreamingDeployFigures(resultsQ3.summaryTable, alphaValues, paperFigures, cfg, ...
    struct("figPrefix", "fig5", "cleanupLegacy", false, ...
    "q1SummaryTable", q1Summary, "globalMaeClim", globalMaeClim, ...
    "globalRelErrorClim", globalRelErrorClim, "globalStopR2Clim", globalStopR2Clim, ...
    "pairTable", q3PairTable));
fprintf("Q0: Fig 5g online LOOCV combo heatmaps...\n");
plotOnlineLoocvComboHeatmaps(resultsQ3.summaryTable, alphaValues, paperFigures, cfg, ...
    struct("figPrefix", "fig5", "q1SummaryTable", q1Summary, ...
    "globalMaeClim", globalMaeClim, "pairTable", q3PairTable));

bestByAlphaTable = selectBestDeployByAlpha(resultsQ3.summaryTable, nan);
writetable(bestByAlphaTable, fullfile(q3Dir, "streaming_deploy_best_by_alpha.csv"));
if istable(bestByAlphaTable) && height(bestByAlphaTable) > 0
    fprintf("Q0: Fig 5e best-by-alpha (stop error) leaderboard...\n");
    results.fig5e = plotBestDeployByAlphaFigures(bestByAlphaTable, paperFigures, cfg, ...
        struct("figPrefix", "fig5e"));
    results.bestByAlphaTable = bestByAlphaTable;
end
results.fig5Dir = paperFigures;

summaryMd = composePaperReportSummary(results);
fid = fopen(fullfile(cfg.out.q0, "paper_report_summary.md"), "w");
fprintf(fid, "%s", summaryMd);
fclose(fid);

fprintf("Q0 論文用レポ�Eト完亁E %s\n", cfg.out.q0);

end

function txt = composePaperReportSummary(results)
txt = "# Paper Report Summary" + newline + newline;
txt = txt + sprintf("- Cohort n=%d" + newline, results.cohort.n);
if isfield(results, "table2") && isfield(results.table2, "offline")
    off = results.table2.offline;
    cv = off.cvResults;
    txt = txt + sprintf("- Offline [%s]: MAE=%.2f N (%.1f%%), R2=%.3f" + newline, ...
        off.methodLabel, cv.metrics.mae, off.maePct, cv.metrics.r2);
end
if isfield(results, "q3Deploy") && isfield(results.q3Deploy, "summaryTable")
    pa = 2;
    if isfield(results.q3Deploy, "primaryAlpha")
        pa = results.q3Deploy.primaryAlpha;
    end
    s3 = results.q3Deploy.summaryTable;
    sub = s3(s3.alpha == pa, :);
    sub = sortrows(sub, "safeStopRate", "descend");
    if ~isempty(sub)
        r0 = sub(1, :);
        txt = txt + sprintf("- Q3 best (unconstrained) @alpha=%.1f: %s, safe-stop=%.1f%%" + newline, ...
            pa, string(r0.krMethodKey), 100 * r0.safeStopRate(1));
    end
end
if isfield(results, "bestByAlphaTable") && istable(results.bestByAlphaTable) ...
        && height(results.bestByAlphaTable) > 0
    bb = results.bestByAlphaTable;
    for ai = 1:height(bb)
        r = bb(ai, :);
        if strlength(string(r.krMethodKey(1))) == 0
            txt = txt + sprintf("- Q3 best @alpha=%.1f scope=%s: none feasible" + newline, ...
                r.alpha, string(r.scope));
            continue;
        end
        relPct = 100 * r.relativeStopError_success_mean;
        relSem = 100 * r.relativeStopError_success_sem;
        txt = txt + sprintf( ...
            "- Q3 best @alpha=%.1f scope=%s: %s, safe-stop=%.1f%%, stop MAE=%.2f±%.2f N, rel err=%.1f%%±%.1f%%" + newline, ...
            r.alpha, string(r.scope), string(r.krMethodKey), ...
            100 * r.safeStopRate, r.stopMae_success, r.stopMae_success_sem, relPct, relSem);
    end
end
txt = txt + newline + "Outputs: paper_tables/, paper_figures/" + newline;
end

function tbl = loadBestByAlphaTable(q3Dir, resultsQ3)
tbl = emptyBestByAlphaTable();
if isfield(resultsQ3, "bestByAlphaTable") && istable(resultsQ3.bestByAlphaTable)
    tbl = resultsQ3.bestByAlphaTable;
    return;
end
csvPath = fullfile(q3Dir, "streaming_deploy_best_by_alpha.csv");
if isfile(csvPath)
    tbl = readtable(csvPath);
    return;
end
if isfield(resultsQ3, "summaryTable")
    tbl = selectBestDeployByAlpha(resultsQ3.summaryTable, nan);
end
end

function tbl = emptyBestByAlphaTable()
tbl = table( ...
    double.empty(0, 1), string.empty(0, 1), string.empty(0, 1), string.empty(0, 1), ...
    string.empty(0, 1), double.empty(0, 1), double.empty(0, 1), double.empty(0, 1), ...
    double.empty(0, 1), double.empty(0, 1), double.empty(0, 1), double.empty(0, 1), ...
    double.empty(0, 1), ...
    'VariableNames', { ...
    'alpha', 'scope', 'methodType', 'krMethodKey', 'label', ...
    'safeStopRate', 'stopMae_success', 'stopMae_success_sem', ...
    'relativeStopError_success_mean', 'relativeStopError_success_sem', ...
    'warmupStepsMean', 'warmupSteps_sem', 'nFeasible'});
end
