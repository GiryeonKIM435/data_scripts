function pairTable = loadQ1PairTable(cfg, analysisTag)
%loadQ1PairTable Q1 Wilcoxon ペア比輁ECSV を読み込み

pairTable = table();
if nargin < 2 || strlength(string(analysisTag)) == 0
    if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
        analysisTag = cfg.cache.cohortAnalysisTag;
    else
        analysisTag = "burgers_iqr2";
    end
end
csvPath = fullfile(cfg.out.q1, analysisTag, "kr_methods_vs_best_pairs.csv");
if isfile(csvPath)
    pairTable = readtable(csvPath);
end
end
