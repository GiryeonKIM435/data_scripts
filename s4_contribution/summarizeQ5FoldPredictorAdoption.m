function results = summarizeQ5FoldPredictorAdoption(cfg, trackOutDir, caseId)
%summarizeQ5FoldPredictorAdoption Minor 8: fold 内共線性除去後の変数採用率
%
% fold_collinearity_<caseId>.csv から各説明変数の採用 fold 数を集計する。

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 3 || isempty(caseId)
    caseId = "m_all_kr_full";
end
if nargin < 2 || isempty(trackOutDir)
    error("summarizeQ5FoldPredictorAdoption:NeedDir", "trackOutDir が必要です。");
end

logPath = fullfile(trackOutDir, "fold_collinearity_" + string(caseId) + ".csv");
if ~isfile(logPath)
    warning("summarizeQ5FoldPredictorAdoption:NoLog", ...
        "fold log がありません: %s", logPath);
    results = struct("table", table(), "csvPath", "");
    return;
end

L = readtable(logPath);
if ~ismember("foldIdx", L.Properties.VariableNames) ...
        || ~ismember("selectedPredictors", L.Properties.VariableNames)
    warning("summarizeQ5FoldPredictorAdoption:BadLog", "列が不足しています。");
    results = struct("table", table(), "csvPath", "");
    return;
end

% fold ごとに1行（同一 fold の重複行を集約）
foldIds = unique(L.foldIdx);
nFolds = numel(foldIds);
allVars = strings(0, 1);
selectedByFold = cell(nFolds, 1);
for fi = 1:nFolds
    rows = L(L.foldIdx == foldIds(fi), :);
    selStr = string(rows.selectedPredictors(1));
    if strlength(selStr) == 0
        selectedByFold{fi} = strings(0, 1);
    else
        selectedByFold{fi} = split(selStr, "|");
    end
    allVars = unique([allVars; selectedByFold{fi}(:)], "stable");
end

nAdopt = zeros(numel(allVars), 1);
for vi = 1:numel(allVars)
    v = allVars(vi);
    for fi = 1:nFolds
        if any(selectedByFold{fi} == v)
            nAdopt(vi) = nAdopt(vi) + 1;
        end
    end
end

rate = nAdopt / max(nFolds, 1);
T = table(allVars, nAdopt, rate, nFolds * ones(numel(allVars), 1), ...
    'VariableNames', {'predictor', 'nFoldsAdopted', 'adoptionRate', 'nFolds'});
T = sortrows(T, "adoptionRate", "descend");

csvPath = fullfile(trackOutDir, "table_fold_predictor_adoption_" + string(caseId) + ".csv");
writetable(T, csvPath);
if isfield(cfg, "out") && isfield(cfg.out, "paperTables")
    writetable(T, fullfile(cfg.out.paperTables, ...
        "table_fold_predictor_adoption_" + string(caseId) + ".csv"));
end

results = struct();
results.createdAt = datetime("now");
results.caseId = string(caseId);
results.table = T;
results.csvPath = csvPath;
results.nFolds = nFolds;
fprintf("Q5 fold adoption (%s): %d folds, %d predictors -> %s\n", ...
    caseId, nFolds, height(T), csvPath);
end
