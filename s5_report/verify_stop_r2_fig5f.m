function verify_stop_r2_fig5f()
%verify_stop_r2_fig5f stopR2_success 陬懷ｮ後・fig5f 逕滓・繝ｻ蜿ら・ Rﾂｲ 荳閾ｴ遒ｺ隱・

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

assert(ismember("stopR2_success", summary.Properties.VariableNames), ...
    "stopR2_success column missing after augment");
assert(any(isfinite(summary.stopR2_success)), "stopR2_success all NaN");

outDir = q3Dir;
alphaValues = cfg.deploy.alphaValues(:);
globalStopR2Clim = computeGlobalStopR2HeatmapClim(summary, cfg);
plotStreamingDeployFigures(summary, alphaValues, outDir, cfg, struct( ...
    "figPrefix", "fig5", "cleanupLegacy", false, ...
    "globalStopR2Clim", globalStopR2Clim));

methodTypes = activeKrMethodTypes();
prefixByType = struct( ...
    "percent_yield", "yield_pct", ...
    "force_abs", "force_abs", ...
    "force_trailing", "force_trail");
nFigExpected = 0;
for ai = 1:numel(alphaValues)
    a = alphaValues(ai);
    aTag = formatAlphaTagForVerify(a);
    for ti = 1:numel(methodTypes)
        mt = methodTypes{ti};
        sub = summary(summary.alpha == a & string(summary.methodType) == mt, :);
        if isempty(sub)
            continue;
        end
        [valueMat, ~, ~, ~, ~] = buildKrGridMatrices(sub, "stopR2_success", "", mt);
        if isempty(valueMat) || all(isnan(valueMat(:)))
            continue;
        end
        nFigExpected = nFigExpected + 1;
        figName = sprintf("fig5f_stop_r2_%s_%s.png", prefixByType.(mt), aTag);
        figPath = fullfile(outDir, figName);
        assert(isfile(figPath), "fig5f missing: %s", figPath);
        fprintf("OK: %s\n", figPath);
    end
end
assert(nFigExpected >= 3, "expected at least 3 fig5f outputs, got %d", nFigExpected);

% force_s00_w20 @ alpha=2 vs per-sample Rﾂｲ
targetKey = "force_s00_w20";
targetAlpha = 2;
sub = perSample(string(perSample.krMethodKey) == targetKey ...
    & perSample.alpha == targetAlpha ...
    & string(perSample.outcome) == "success", :);
assert(height(sub) >= 2, "insufficient success rows for %s alpha=%g", targetKey, targetAlpha);
m = calcMetrics(sub.yTrue, sub.y_hat_at_stop);
row = summary(string(summary.krMethodKey) == targetKey & summary.alpha == targetAlpha, :);
assert(height(row) == 1, "summary row not unique for %s alpha=%g", targetKey, targetAlpha);
diffR2 = abs(row.stopR2_success - m.r2);
fprintf("force_s00_w20 @ alpha=2: summary R2=%.6f, per-sample R2=%.6f, diff=%.2e\n", ...
    row.stopR2_success, m.r2, diffR2);
assert(diffR2 < 1e-10, "stopR2_success mismatch for reference case");

fprintf("verify_stop_r2_fig5f: all checks passed.\n");

end

function aTag = formatAlphaTagForVerify(alpha)
aTag = "a" + strrep(sprintf("%.1f", alpha), ".", "");
end
