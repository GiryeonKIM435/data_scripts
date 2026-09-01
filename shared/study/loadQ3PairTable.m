function pairTable = loadQ3PairTable(cfg, analysisTag)
%loadQ3PairTable Q3 Wilcoxon ペア比較 CSV を読み込み（なければ per-sample から再計算）

pairTable = table();
if nargin < 2 || strlength(string(analysisTag)) == 0
    analysisTag = resolvePaperQ3AnalysisTag(cfg);
end
csvPath = fullfile(cfg.out.q3, analysisTag, "streaming_deploy_vs_best_pairs.csv");
if isfile(csvPath)
    pairTable = readtable(csvPath);
    return;
end

perCsv = fullfile(cfg.out.q3, analysisTag, "streaming_deploy_per_sample.csv");
summaryCsv = fullfile(cfg.out.q3, analysisTag, "streaming_deploy_summary.csv");
if isfile(perCsv) && isfile(summaryCsv)
    perSample = readtable(perCsv);
    summaryTable = readtable(summaryCsv);
    alphaValues = cfg.deploy.alphaValues(:);
    if ismember("alpha", summaryTable.Properties.VariableNames)
        alphaValues = unique(summaryTable.alpha);
    end
    pairTable = compareStreamingDeployMethodsToBest(perSample, summaryTable, alphaValues);
end
end
