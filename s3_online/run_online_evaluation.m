function results = run_online_evaluation(cfg, opts)
%RUN_ONLINE_EVALUATION Results 4.3: sequential replay (design alpha095)
%
% Paper products only:
%   - Final-update MAE + bioyield + premature heatmap (fig:res_heatmap b)
%   - sequential-replay control example (fig:res_online_example)
%   - design-best CSV for downstream 4.4 key resolution helpers
%
% Core Q7 deploy + premature counts + Wilcoxon pairs are retained.

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = cfg.q7.useOutlierFilter;
end
if ~isfield(opts, "reuseExisting")
    opts.reuseExisting = true;
end
if ~isfield(opts, "writeFigures")
    opts.writeFigures = true;
end
writeFigures = logical(opts.writeFigures);
if ~isfield(opts, "analysisTag") || strlength(string(opts.analysisTag)) == 0
    analysisTag = resolveQ7AnalysisTag(cfg, struct());
else
    analysisTag = string(opts.analysisTag);
end

gammaTag = "gamma_" + strrep(sprintf("%.1f", cfg.q7.gammaValues(1)), ".", "p");
outDirTag = fullfile(cfg.out.q7, analysisTag);
outDirGamma = fullfile(outDirTag, gammaTag);
resPath = fullfile(outDirTag, "q7_design_alpha_deploy_results.mat");

q7 = [];
if opts.reuseExisting && isfile(resPath)
    s = load(resPath, "results");
    if isfield(s, "results") && isfield(s.results, "designSummary")
        q7 = s.results;
        fprintf("4.3 sequential replay: reusing existing Q7 results (%s)\n", resPath);
    end
end
if isempty(q7)
    fprintf("4.3 sequential replay: running design-alpha095 deploy...\n");
    q7Opts = struct("useOutlierFilter", opts.useOutlierFilter);
    if isfield(opts, "analysisTag") && strlength(string(opts.analysisTag)) > 0
        q7Opts.analysisTag = string(opts.analysisTag);
    end
    q7 = run_q7_design_alpha_deploy_study(cfg, q7Opts);
end

designSummary = q7.designSummary;
designPerSample = q7.designPerSample;
alphaSlice = cfg.q7.designAlphaSlice;
[designPerSample, designSummary] = normalizeQ7DesignAlphaSlice( ...
    designPerSample, designSummary, alphaSlice);
try
    [designPerSample, designSummary] = augmentQ7OnlineSafetyMetrics( ...
        designPerSample, designSummary);
catch ME
    warning("run_online_evaluation:SafetyMetrics", "%s", ME.message);
end
designPair = [];
if isfield(q7, "byGamma") && ~isempty(q7.byGamma) && isfield(q7.byGamma{1}, "designPair")
    designPair = q7.byGamma{1}.designPair;
end
if isfield(q7, "cohort") && ~isempty(q7.cohort)
    cohort = q7.cohort;
else
    cohort = loadStudyCohort(cfg, struct("useOutlierFilter", opts.useOutlierFilter));
end

designBest = selectQ7DesignBestByScope(designSummary, struct( ...
    "bestSelectionMode", cfg.q7.bestSelectionMode));

q1Summary = loadQ1SummaryTable(cfg, analysisTag);
pairByType = buildOnlinePairByType(designSummary, designPerSample, alphaSlice, outDirGamma, cfg);

earlyTbl = countOnlineEarlyStopsByMethod(designPerSample, designSummary);
writetable(earlyTbl, fullfile(outDirGamma, "table_online_early_stop_by_method.csv"));

bestAbs = extractBestRow(designBest, "force_abs");
fprintf("4.3 sequential best: abs=%s (alpha_0.95=%.3f, Final-update MAE=%.2f N, fail=%d)\n", ...
    bestAbs.krMethodKey, bestAbs.alphaDesign, bestAbs.finalUpdateMae, bestAbs.nSafeStopFail);

if ~isempty(designBest)
    writetable(designBest, fullfile(outDirGamma, "q7_design_best_by_scope.csv"));
end

examplePath = "";
if writeFigures
    plotOnlineMaeBioyieldPrematureHeatmaps(designSummary, earlyTbl, pairByType, ...
        q1Summary, outDirGamma, cfg);

    exampleMethod = string(cfg.paper.exampleMethodKey);
    if strlength(exampleMethod) == 0
        exampleMethod = string(bestAbs.krMethodKey);
    end
    exampleSampleId = cfg.paper.exampleSampleId;
    exampleAlpha = resolveExampleFoldAlpha(designPerSample, exampleMethod, ...
        exampleSampleId, bestAbs.alphaDesign);
    fprintf("4.3 sequential example: id=%d alpha_0.95^(-i)=%.3f (method=%s)\n", ...
        exampleSampleId, exampleAlpha, exampleMethod);
    examplePath = plotOnlineExampleCase(cfg, cohort, exampleMethod, ...
        exampleAlpha, outDirGamma, exampleSampleId);
end

results = struct();
results.createdAt = datetime("now");
results.analysisTag = analysisTag;
results.gammaTag = char(gammaTag);
results.q7 = q7;
results.designSummary = designSummary;
results.designPerSample = designPerSample;
results.designBest = designBest;
results.designPair = designPair;
results.pairByType = pairByType;
results.bestAbs = bestAbs;
results.examplePath = examplePath;
results.outputDir = outDirGamma;

fprintf("4.3 sequential replay finished: %s\n", outDirGamma);
end

function best = extractBestRow(designBest, scopeId)
best = struct("krMethodKey", "", "label", "", "alphaDesign", nan, ...
    "finalUpdateMae", nan, "safeStopRate", nan, "nSafeStopFail", nan);
if isempty(designBest)
    return;
end
row = designBest(string(designBest.scope) == string(scopeId), :);
if isempty(row) || strlength(string(row.krMethodKey(1))) == 0
    return;
end
best.krMethodKey = string(row.krMethodKey(1));
best.label = string(row.label(1));
best.alphaDesign = row.alphaDesign(1);
best.finalUpdateMae = row.finalUpdateMae(1);
best.safeStopRate = row.safeStopRate(1);
if ismember("nSafeStopFail", row.Properties.VariableNames)
    best.nSafeStopFail = row.nSafeStopFail(1);
end
end

function alpha = resolveExampleFoldAlpha(designPerSample, methodKey, sampleId, fallback)
alpha = fallback;
if isempty(designPerSample)
    return;
end
sub = designPerSample(string(designPerSample.krMethodKey) == string(methodKey) ...
    & designPerSample.id == sampleId, :);
if isempty(sub)
    return;
end
if ismember("alphaDesign", sub.Properties.VariableNames) && isfinite(sub.alphaDesign(1))
    alpha = sub.alphaDesign(1);
elseif isfinite(sub.alpha(1))
    alpha = sub.alpha(1);
end
end

function pairByType = buildOnlinePairByType(designSummary, designPerSample, alphaSlice, outDir, cfg)
pairByType = struct();
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");
methodTypes = cfg.q7.methodTypes(:);
if isempty(methodTypes)
    methodTypes = "force_abs";
end

for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    sumSub = designSummary(string(designSummary.methodType) == mt, :);
    if isempty(sumSub)
        pairByType.(char(mt)) = table();
        continue;
    end
    keys = unique(string(sumSub.krMethodKey));
    if isempty(designPerSample)
        perSub = table();
    else
        perSub = designPerSample(ismember(string(designPerSample.krMethodKey), keys), :);
    end
    pairTbl = compareStreamingDeployMethodsToBest(perSub, sumSub, alphaSlice);
    pairByType.(char(mt)) = pairTbl;
    prefix = prefixByType.(char(mt));
    writetable(pairTbl, fullfile(outDir, "q7_design_vs_best_pairs_" + prefix + ".csv"));
    if ~isempty(pairTbl) && ismember("qValueBH", pairTbl.Properties.VariableNames)
        fprintf("4.3 sequential pairs [%s]: reference=%s, nCompare=%d, nondiff(q>=0.05)=%d\n", ...
            prefix, string(pairTbl.referenceMethod(1)), height(pairTbl), ...
            sum(isfinite(pairTbl.qValueBH) & pairTbl.qValueBH >= 0.05));
    end
end
end
