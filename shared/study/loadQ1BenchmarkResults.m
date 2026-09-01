function results = loadQ1BenchmarkResults(cfg, analysisTag)
%loadQ1BenchmarkResults Q1 LOOCV ベンチ�Eーク結果�E�EvResults 含む�E�を読み込み

results = [];
if nargin < 2 || isempty(analysisTag)
    if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
        analysisTag = cfg.cache.cohortAnalysisTag;
    else
        analysisTag = "burgers_no_iqr";
    end
end

matPath = fullfile(cfg.out.q1, analysisTag, "kr_benchmark_results.mat");
if ~isfile(matPath)
    return;
end
s = load(matPath, "results");
if isfield(s, "results")
    results = s.results;
end

end
