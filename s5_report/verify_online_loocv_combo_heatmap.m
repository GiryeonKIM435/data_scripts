function verify_online_loocv_combo_heatmap()
%verify_online_loocv_combo_heatmap fig5g 統合ヒート�EチE�Eの生�E・冁E��確誁E

setup_paths();
cfg = ensurePipelineReady();
cfg.deploy.krVariant = "ls";
cfg = syncPaperKrVariant(cfg);

q3Tag = "primary_mad_on_ls";
q3Dir = fullfile(cfg.out.q3, q3Tag);
if ~isfile(fullfile(q3Dir, "streaming_deploy_summary.csv"))
    q3Tag = resolvePaperQ3AnalysisTag(cfg);
    q3Dir = fullfile(cfg.out.q3, q3Tag);
end
fprintf("verify: Q3 dir = %s\n", q3Dir);

summaryPath = fullfile(q3Dir, "streaming_deploy_summary.csv");
perPath = fullfile(q3Dir, "streaming_deploy_per_sample.csv");
assert(isfile(summaryPath), "summary missing: %s", summaryPath);
assert(isfile(perPath), "per_sample missing: %s", perPath);

summary = readtable(summaryPath);
perSample = readtable(perPath);
[summary, ~] = filterKrSummaryToRegistry(summary, cfg, "Q3");
summary = augmentStreamingDeploySummaryWithStopR2(summary, perSample);

q1Tag = "burgers_iqr2";
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
    q1Tag = cfg.cache.cohortAnalysisTag;
end
q1Summary = loadQ1SummaryTable(cfg, q1Tag);
[q1Summary, ~] = filterKrSummaryToRegistry(q1Summary, cfg, "Q1");
q3PairTable = loadQ3PairTable(cfg, q3Tag);
globalMaeClim = computeGlobalMaeHeatmapClim(q1Summary, summary, cfg);

alphaValues = cfg.deploy.alphaValues(:);
plotOnlineLoocvComboHeatmaps(summary, alphaValues, q3Dir, cfg, struct( ...
    "figPrefix", "fig5", "q1SummaryTable", q1Summary, ...
    "globalMaeClim", globalMaeClim, "pairTable", q3PairTable));

q1Best = resolveQ1BestMethodKey(q1Summary, cfg);
fprintf("Q1 best key: %s\n", q1Best);
assert(strcmp(q1Best, "ftrail_f30_w30"), ...
    "expected Q1 best ftrail_f30_w30, got %s", q1Best);

methodTypes = activeKrMethodTypes();
prefixByType = struct( ...
    "percent_yield", "yield_pct", ...
    "force_abs", "force_abs", ...
    "force_trailing", "force_trail");
nFigExpected = 0;
for ai = 1:numel(alphaValues)
    aTag = formatVerifyAlphaTag(alphaValues(ai));
    for ti = 1:numel(methodTypes)
        mt = methodTypes{ti};
        sub = summary(summary.alpha == alphaValues(ai) ...
            & string(summary.methodType) == mt, :);
        if isempty(sub)
            continue;
        end
        [maeMat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "stopMae_success", "", mt);
        if isempty(maeMat) || all(isnan(maeMat(:)))
            continue;
        end
        nFigExpected = nFigExpected + 1;
        figName = sprintf("fig5g_online_loocv_combo_%s_%s.png", prefixByType.(mt), aTag);
        figPath = fullfile(q3Dir, figName);
        assert(isfile(figPath), "fig5g missing: %s", figPath);
        fprintf("OK: %s\n", figPath);
    end
end
assert(nFigExpected >= 3, "expected at least 3 fig5g outputs, got %d", nFigExpected);

targetKey = "force_s00_w20";
targetAlpha = 2;
row = summary(string(summary.krMethodKey) == targetKey & summary.alpha == targetAlpha, :);
assert(height(row) == 1, "summary row missing for %s alpha=%g", targetKey, targetAlpha);
fprintf("force_s00_w20 @ alpha=2: MAE=%.4f, R2=%.6f, SSR=%.1f%%\n", ...
    row.stopMae_success, row.stopR2_success, 100 * row.safeStopRate);
assert(abs(row.stopMae_success - 10.402) < 0.05, "unexpected stop MAE");
assert(abs(row.stopR2_success - 0.519) < 0.01, "unexpected stop R2");
assert(row.safeStopRate >= 0.999, "expected SSR ~100%%");

refIdx = findKrGridCellIndex(q1Best, "force_trailing");
assert(~isempty(refIdx), "Q1 best cell index missing for force_trailing");

fprintf("verify_online_loocv_combo_heatmap: all checks passed.\n");

end

function aTag = formatVerifyAlphaTag(alpha)
aTag = "a" + strrep(sprintf("%.1f", alpha), ".", "");
end
