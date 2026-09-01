function results = replot_online_example(cfg, opts)
%REPLOT_ONLINE_EXAMPLE 論文 fig:res_online_example のみ再描画（Q7 再計算なし）
%
% 既存の Q7 設計αデプロイ成果物から fold 別 α を読み、
% plotOnlineExampleCase で例示図だけ出力する。

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = cfg.q7.useOutlierFilter;
end
if ~isfield(opts, "analysisTag") || strlength(string(opts.analysisTag)) == 0
    analysisTag = resolveQ7AnalysisTag(cfg, struct());
else
    analysisTag = string(opts.analysisTag);
end

gammaTag = "gamma_" + strrep(sprintf("%.1f", cfg.q7.gammaValues(1)), ".", "p");
outDirTag = fullfile(cfg.out.q7, analysisTag);
outDirGamma = fullfile(outDirTag, gammaTag);
if ~isfolder(outDirGamma)
    mkdir(outDirGamma);
end

designPerSample = loadDesignPerSampleForExample(outDirTag, outDirGamma);

exampleMethod = string(cfg.paper.exampleMethodKey);
exampleSampleId = cfg.paper.exampleSampleId;
fallbackAlpha = cfg.deploy.primaryAlpha;
if isfield(cfg, "paper") && isfield(cfg.paper, "exampleAlpha") ...
        && isfinite(cfg.paper.exampleAlpha)
    fallbackAlpha = cfg.paper.exampleAlpha;
end

exampleAlpha = resolveExampleFoldAlpha(designPerSample, exampleMethod, ...
    exampleSampleId, fallbackAlpha);

cohort = loadStudyCohort(cfg, struct("useOutlierFilter", opts.useOutlierFilter));

fprintf("4.3 online example replot: id=%d alpha_0.95^(-i)=%.3f (method=%s)\n", ...
    exampleSampleId, exampleAlpha, exampleMethod);

examplePath = plotOnlineExampleCase(cfg, cohort, exampleMethod, ...
    exampleAlpha, outDirGamma, exampleSampleId);

results = struct();
results.createdAt = datetime("now");
results.analysisTag = char(analysisTag);
results.gammaTag = char(gammaTag);
results.exampleMethod = char(exampleMethod);
results.exampleSampleId = exampleSampleId;
results.exampleAlpha = exampleAlpha;
results.examplePath = examplePath;
results.outputDir = outDirGamma;
fprintf("4.3 online example replot 完了: %s\n", examplePath);
end

function designPerSample = loadDesignPerSampleForExample(outDirTag, outDirGamma)
designPerSample = table();
resPath = fullfile(outDirTag, "q7_design_alpha_deploy_results.mat");
csvPath = fullfile(outDirGamma, "q7_design_alpha_per_sample.csv");
if ~isfile(csvPath)
    csvPath = fullfile(outDirTag, "q7_design_alpha_per_sample.csv");
end

if isfile(resPath)
    s = load(resPath, "results");
    if isfield(s, "results") && isfield(s.results, "designPerSample")
        designPerSample = s.results.designPerSample;
        return;
    end
end

if isfile(csvPath)
    designPerSample = readtable(csvPath);
    return;
end

error("replot_online_example:MissingQ7", ...
    ["Q7 成果物がありません。先に doOnline を実行するか、次のいずれかを用意してください:\n" ...
    "  %s\n  %s"], resPath, csvPath);
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
elseif ismember("alpha", sub.Properties.VariableNames) && isfinite(sub.alpha(1))
    alpha = sub.alpha(1);
end
end
