function tbl = loadQ1SummaryTable(cfg, analysisTag)
%loadQ1SummaryTable Q1 LOOCV サマリ表を読み込み�E�なければ空 table�E�E

tbl = table();
if nargin < 2 || isempty(analysisTag)
    if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
        analysisTag = cfg.cache.cohortAnalysisTag;
    else
        analysisTag = "burgers_iqr2";
    end
end

matPath = fullfile(cfg.out.q1, analysisTag, "kr_benchmark_results.mat");
if isfile(matPath)
    s = load(matPath, "results");
    if isfield(s, "results") && isfield(s.results, "summaryTable")
        tbl = s.results.summaryTable;
        return;
    end
end

csvPath = fullfile(cfg.out.q1, analysisTag, "kr_methods_loocv_summary.csv");
if isfile(csvPath)
    tbl = readtable(csvPath);
end

end
