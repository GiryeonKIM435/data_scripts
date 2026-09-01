function bestTable = selectBestDeployByAlpha(summaryTable, alpha)
%selectBestDeployByAlpha α ごと・方式種別ごとの stop error 最小方式
%
% ランキング: stopMae_success -> relativeStopError_success_mean -> warmupStepsMean
% alpha 省略時は summaryTable の全 alpha

if nargin < 2 || isempty(alpha)
    alpha = nan;
end

scopes = {
    struct("id", "overall", "methodType", "")
    struct("id", "yield_pct", "methodType", "percent_yield")
    struct("id", "force_abs", "methodType", "force_abs")
    struct("id", "force_trail", "methodType", "force_trailing")};

rows = cell(0, 13);
alphas = uniqueAlphaValues(summaryTable, alpha);

for ai = 1:numel(alphas)
    aVal = alphas(ai);
    subAlpha = summaryTable(abs(summaryTable.alpha - aVal) < 1e-9, :);
    for si = 1:numel(scopes)
        sdef = scopes{si};
        [bestRow, nFeasible] = pickBestDeployRow(subAlpha, sdef);
        rows(end + 1, :) = packBestRow(bestRow, sdef, aVal, nFeasible); %#ok<AGROW>
    end
end

if isempty(rows)
    bestTable = emptyBestDeployByAlphaTable();
    return;
end

bestTable = cell2table(rows, 'VariableNames', { ...
    'alpha', 'scope', 'methodType', ...
    'krMethodKey', 'label', 'safeStopRate', 'stopMae_success', 'stopMae_success_sem', ...
    'relativeStopError_success_mean', 'relativeStopError_success_sem', ...
    'warmupStepsMean', 'warmupSteps_sem', 'nFeasible'});

strCols = ["scope", "methodType", "krMethodKey", "label"];
for i = 1:numel(strCols)
    c = strCols(i);
    if ismember(c, bestTable.Properties.VariableNames)
        bestTable.(c) = fillmissing(string(bestTable.(c)), "constant", "");
    end
end

end

function alphas = uniqueAlphaValues(summaryTable, alpha)
if nargin >= 2 && isfinite(alpha)
    alphas = alpha;
    return;
end
if ~ismember("alpha", summaryTable.Properties.VariableNames)
    alphas = nan;
    return;
end
alphas = unique(summaryTable.alpha);
alphas = alphas(isfinite(alphas));
end

function [bestRow, nFeasible] = pickBestDeployRow(subAlpha, sdef)
bestRow = [];
nFeasible = 0;
if isempty(subAlpha)
    return;
end

sub = subAlpha;
if strlength(string(sdef.methodType)) > 0
    sub = sub(string(sub.methodType) == string(sdef.methodType), :);
end
if isempty(sub)
    return;
end

mask = true(height(sub), 1);
if ismember("gridValid", sub.Properties.VariableNames)
    mask = mask & logical(sub.gridValid);
end
if ismember("stopMae_success", sub.Properties.VariableNames)
    mask = mask & isfinite(sub.stopMae_success);
end

feasible = sub(mask, :);
nFeasible = height(feasible);
if nFeasible == 0
    return;
end

feasible = sortrows(feasible, ...
    ["stopMae_success", "relativeStopError_success_mean", "warmupStepsMean"], ...
    ["ascend", "ascend", "ascend"], "MissingPlacement", "last");
bestRow = feasible(1, :);
end

function row = packBestRow(bestRow, sdef, alpha, nFeasible)
if isempty(bestRow)
    row = {alpha, char(sdef.id), char(sdef.methodType), ...
        "", "", nan, nan, nan, nan, nan, nan, nan, nFeasible};
    return;
end
warmupSem = nan;
if ismember("warmupSteps_sem", bestRow.Properties.VariableNames)
    warmupSem = bestRow.warmupSteps_sem;
end
row = {alpha, char(sdef.id), char(sdef.methodType), ...
    char(bestRow.krMethodKey), char(bestRow.label), bestRow.safeStopRate, ...
    bestRow.stopMae_success, bestRow.stopMae_success_sem, ...
    bestRow.relativeStopError_success_mean, bestRow.relativeStopError_success_sem, ...
    bestRow.warmupStepsMean, warmupSem, nFeasible};
end

function tbl = emptyBestDeployByAlphaTable()
tbl = table( ...
    double.empty(0, 1), string.empty(0, 1), string.empty(0, 1), ...
    string.empty(0, 1), string.empty(0, 1), double.empty(0, 1), ...
    double.empty(0, 1), double.empty(0, 1), double.empty(0, 1), double.empty(0, 1), ...
    double.empty(0, 1), double.empty(0, 1), double.empty(0, 1), ...
    'VariableNames', { ...
    'alpha', 'scope', 'methodType', ...
    'krMethodKey', 'label', 'safeStopRate', 'stopMae_success', 'stopMae_success_sem', ...
    'relativeStopError_success_mean', 'relativeStopError_success_sem', ...
    'warmupStepsMean', 'warmupSteps_sem', 'nFeasible'});
end
