function u = pipelineUtils()
%pipelineUtils パイプライン共通ユーティリティ

u = struct( ...
    "ensureDir", @ensureDir, ...
    "buildAnalyzePaths", @buildAnalyzePaths, ...
    "writeOutlierCsv", @writeOutlierCsv, ...
    "printCohortSummary", @printCohortSummary, ...
    "zscoreSafe", @zscoreSafe, ...
    "getfieldOrDefault", @getfieldOrDefault);

end

function ensureDir(d)
if ~isfolder(d)
    mkdir(d);
end
end

function paths = buildAnalyzePaths(cfg, runStem, subDir)
if nargin < 3
    subDir = "";
end
if strlength(string(subDir)) > 0
    runDir = fullfile(cfg.out.analyze, runStem, subDir);
    resultStem = runStem + "_" + string(subDir);
else
    runDir = fullfile(cfg.out.analyze, runStem);
    resultStem = runStem;
end
figDir = fullfile(runDir, "figures");
ensureDir(runDir);
ensureDir(figDir);
paths = struct( ...
    "runDir", string(runDir), ...
    "figDir", string(figDir), ...
    "resultMat", string(fullfile(runDir, resultStem + "_results.mat")), ...
    "datasetCsv", string(fullfile(runDir, resultStem + "_dataset.csv")), ...
    "outlierCsv", string(fullfile(runDir, resultStem + "_outliers.csv")));
end

function writeOutlierCsv(outlierLog, csvPath)
if isempty(outlierLog)
    writetable(table(), csvPath);
    return;
end
n = numel(outlierLog);
rowIndex = nan(n, 1);
id = nan(n, 1);
reason = strings(n, 1);
variable = strings(n, 1);
score = nan(n, 1);
for k = 1:n
    rowIndex(k) = outlierLog(k).rowIndex;
    id(k) = outlierLog(k).id;
    reason(k) = string(outlierLog(k).reason);
    variable(k) = string(outlierLog(k).variable);
    score(k) = outlierLog(k).score;
end
writetable(table(rowIndex, id, reason, variable, score), csvPath);
end

function printCohortSummary(cohort)
fprintf("コホート: n=%d, useOutlierFilter=%d\n", cohort.n, cohort.useOutlierFilter);
fprintf("  IDs (先頭10): %s\n", mat2str(cohort.ids(1:min(10, cohort.n)).'));
end

function [Z, mu, sigma] = zscoreSafe(X)
mu = mean(X, 1, "omitnan");
sigma = std(X, 0, 1, "omitnan");
sigma(sigma == 0) = 1;
Z = (X - mu) ./ sigma;
end

function v = getfieldOrDefault(s, name, defaultValue)
if isstruct(s) && isfield(s, name)
    v = s.(name);
else
    v = defaultValue;
end
end
