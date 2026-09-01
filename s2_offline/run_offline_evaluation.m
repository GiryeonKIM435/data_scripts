function results = run_offline_evaluation(cfg, opts)
%RUN_OFFLINE_EVALUATION Results 4.2: post-test LOOCV (chord stiffness k)
%
% Paper term: post-test evaluation. Legacy name: offline / Q1.
% Absolute-force intervals only (force_abs). Writes:
%   - LOOCV summary + Wilcoxon/BH pairs for heatmap frames
%   - MAE±SEM / R^2 heatmap (paper fig:res_heatmap a)
%
% Non-significant frames use the best method within methodType.

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "analysisTag")
    if isfield(cfg, "analysis") && isfield(cfg.analysis, "primaryAnalysisTag") ...
            && strlength(string(cfg.analysis.primaryAnalysisTag)) > 0
        opts.analysisTag = string(cfg.analysis.primaryAnalysisTag);
    else
        opts.analysisTag = "burgers_no_iqr";
    end
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
end
if ~isfield(opts, "reuseExisting")
    opts.reuseExisting = true;
end
if ~isfield(opts, "writeFigures")
    opts.writeFigures = true;
end
writeFigures = logical(opts.writeFigures);

outDir = fullfile(cfg.out.q1, opts.analysisTag);
resPath = fullfile(outDir, "kr_benchmark_results.mat");

benchmark = [];
if opts.reuseExisting && isfile(resPath)
    s = load(resPath, "results");
    if isfield(s, "results") && isfield(s.results, "summaryTable")
        benchmark = s.results;
        fprintf("4.2 post-test: reusing existing LOOCV benchmark (%s)\n", resPath);
    end
end
if isempty(benchmark)
    fprintf("4.2 post-test: running LOOCV benchmark...\n");
    benchmark = run_kr_method_benchmark(cfg, struct( ...
        "analysisTag", opts.analysisTag, ...
        "useOutlierFilter", opts.useOutlierFilter, ...
        "commonCaseOnly", false));
end

summary = benchmark.summaryTable;
krVariant = string(cfg.deploy.krVariant);
if ismember("variant", summary.Properties.VariableNames)
    summary = summary(string(summary.variant) == krVariant, :);
end
pairTable = [];
if isfield(benchmark, "pairTable")
    pairTable = benchmark.pairTable;
end

%% methodType 内 best 基準のペア比較（非有意枠用）
pairByType = buildOfflinePairByType(benchmark, summary, krVariant, outDir);

%% Best absolute-force interval (always saved as CSV)
bestAbs = pickBestByType(summary, "force_abs");
fprintf("4.2 post-test best (force_abs): %s (MAE=%.2f N, R2=%.3f)\n", ...
    bestAbs.krMethodKey, bestAbs.mae, bestAbs.r2);

bestTable = table( ...
    "force_abs", ...
    string(bestAbs.krMethodKey), ...
    string(bestAbs.label), ...
    bestAbs.mae, ...
    bestAbs.maeSem, ...
    bestAbs.r2, ...
    'VariableNames', {'methodType', 'krMethodKey', 'label', ...
    'mae_loocv', 'mae_loocv_sem', 'r2_loocv'});
writetable(bestTable, fullfile(outDir, "offline_best_methods.csv"));

%% Figures (optional; paper figures via doFigTable)
if writeFigures
    plotOfflineMaeR2Heatmaps(summary, pairByType, outDir, cfg);
end

results = struct();
results.createdAt = datetime("now");
results.analysisTag = opts.analysisTag;
results.krVariant = char(krVariant);
results.benchmark = benchmark;
results.summaryTable = summary;
results.pairTable = pairTable;
results.pairByType = pairByType;
results.bestTable = bestTable;
results.bestAbsKey = char(bestAbs.krMethodKey);
results.bestTrailKey = "";
results.outputDir = outDir;

fprintf("4.2 post-test finished: %s\n", outDir);
end

function best = pickBestByType(summary, methodType)
sub = summary(string(summary.methodType) == string(methodType), :);
if ismember("gridValid", sub.Properties.VariableNames)
    sub = sub(logical(sub.gridValid), :);
end
sub = sub(isfinite(sub.mae_loocv), :);
if isempty(sub)
    error("run_offline_evaluation:NoRows", ...
        "methodType=%s の有効な LOOCV 行がありません。", methodType);
end
[~, idx] = min(sub.mae_loocv);
best = struct();
best.krMethodKey = string(sub.krMethodKey(idx));
best.label = string(sub.label(idx));
best.mae = sub.mae_loocv(idx);
best.maeSem = sub.mae_loocv_sem(idx);
best.r2 = sub.r2_loocv(idx);
end

function pairByType = buildOfflinePairByType(benchmark, summary, krVariant, outDir)
%buildOfflinePairByType methodType 内 best 基準の Wilcoxon+BH ペア表
pairByType = struct();
prefixByType = struct("force_abs", "force_abs", "force_trailing", "force_trail");
methodTypes = "force_abs";

cvResultsByRow = rebuildOfflineCvResultsByRow(benchmark, summary);
if isempty(cvResultsByRow)
    warning("run_offline_evaluation:NoCvResults", ...
        "cvResults が無いため type内 best ペア表を作れません。グローバル pairTable にフォールバックします。");
    if isfield(benchmark, "pairTable")
        for ti = 1:numel(methodTypes)
            mt = methodTypes(ti);
            pairByType.(char(mt)) = benchmark.pairTable;
        end
    end
    return;
end

for ti = 1:numel(methodTypes)
    mt = methodTypes(ti);
    mask = string(summary.methodType) == mt;
    if ismember("variant", summary.Properties.VariableNames)
        mask = mask & (string(summary.variant) == string(krVariant));
    end
    sub = summary(mask, :);
    cvSub = cvResultsByRow(mask);
    if isempty(sub)
        pairByType.(char(mt)) = table();
        continue;
    end
    pairTbl = compareMethodsToBestWilcoxon(sub, cvSub, struct( ...
        "metricField", "mae_loocv", ...
        "pairingMode", "all"));
    pairByType.(char(mt)) = pairTbl;
    prefix = prefixByType.(char(mt));
    writetable(pairTbl, fullfile(outDir, "kr_methods_vs_best_pairs_" + prefix + ".csv"));
    if ~isempty(pairTbl)
        fprintf("4.2 offline pairs [%s]: reference=%s, nCompare=%d, nondiff(q>=0.05)=%d\n", ...
            prefix, string(pairTbl.referenceMethod(1)), height(pairTbl), ...
            sum(isfinite(pairTbl.qValueBH) & pairTbl.qValueBH >= 0.05));
    end
end
end

function cvResultsByRow = rebuildOfflineCvResultsByRow(benchmark, summary)
cvResultsByRow = {};
if ~isfield(benchmark, "cvResults") || isempty(benchmark.cvResults) ...
        || ~isfield(benchmark, "methodKeys") || ~isfield(benchmark, "q1Variants")
    return;
end
methodKeys = string(benchmark.methodKeys(:));
variants = string(benchmark.q1Variants(:));
cvResults = benchmark.cvResults;
cvResultsByRow = cell(height(summary), 1);
for ri = 1:height(summary)
    key = string(summary.krMethodKey(ri));
    var = "";
    if ismember("variant", summary.Properties.VariableNames)
        var = string(summary.variant(ri));
    end
    mi = find(methodKeys == key, 1);
    vi = find(variants == var, 1);
    if isempty(vi) && numel(variants) == 1
        vi = 1;
    end
    if isempty(mi) || isempty(vi)
        cvResultsByRow{ri} = struct("yTrue", [], "yPred", []);
    else
        cvResultsByRow{ri} = cvResults{mi, vi};
    end
end
end
