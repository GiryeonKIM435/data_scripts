function bestTable = selectQ7DesignBestByScope(summaryTable, opts)
%selectQ7DesignBestByScope Design トラック最良方式
%
% opts.bestSelectionMode:
%   "feasibleFirst" (既定) — feasible 優先後に Final-update MAE 最小
%   "minFinalUpdateMae" / "minStopMae" — feasible 無視で Final-update MAE 最小

if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "bestSelectionMode") || strlength(string(opts.bestSelectionMode)) == 0
    opts.bestSelectionMode = "feasibleFirst";
end
selectionMode = lower(string(opts.bestSelectionMode));
if selectionMode == "minstopmae"
    selectionMode = "minfinalupdatemae";
end

scopes = {
    struct("id", "overall", "methodType", "")
    struct("id", "force_abs", "methodType", "force_abs")
    struct("id", "force_trail", "methodType", "force_trailing")};

rows = cell(0, 16);
for si = 1:numel(scopes)
    sdef = scopes{si};
    [bestRow, nFeasible, nCand] = pickBest(summaryTable, sdef, selectionMode);
    rows(end + 1, :) = packRow(bestRow, sdef, nFeasible, nCand); %#ok<AGROW>
end

bestTable = cell2table(rows, 'VariableNames', { ...
    'scope', 'methodType', 'krMethodKey', 'label', 'alphaDesign', 'feasible', ...
    'safeStopRate', 'finalUpdateMae', 'finalUpdateMae_sem', ...
    'relativeFinalUpdateError_mean', 'relativeFinalUpdateError_sem', ...
    'nSafeStopFail', 'nEvaluated', ...
    'stopMae_success', 'nFeasible', 'nCandidates'});

strCols = ["scope", "methodType", "krMethodKey", "label"];
for i = 1:numel(strCols)
    c = strCols(i);
    bestTable.(c) = fillmissing(string(bestTable.(c)), "constant", "");
end
end

function [bestRow, nFeasible, nCand] = pickBest(summaryTable, sdef, selectionMode)
bestRow = [];
nFeasible = 0;
nCand = 0;
if isempty(summaryTable)
    return;
end
sub = summaryTable;
if strlength(string(sdef.methodType)) > 0
    sub = sub(string(sub.methodType) == string(sdef.methodType), :);
end
nCand = height(sub);
if nCand == 0
    return;
end

maeField = resolveFinalUpdateMaeField(sub);
mask = true(height(sub), 1);
if ismember("gridValid", sub.Properties.VariableNames)
    mask = mask & logical(sub.gridValid);
end
if ~isempty(maeField)
    mask = mask & isfinite(sub.(maeField));
end
cand = sub(mask, :);
if isempty(cand)
    return;
end

if ismember("feasible", cand.Properties.VariableNames)
    feas = cand(logical(cand.feasible), :);
    nFeasible = height(feas);
    if selectionMode == "feasiblefirst" && nFeasible > 0
        cand = feas;
    end
else
    nFeasible = height(cand);
end

sortCols = string(maeField);
if ismember("relativeFinalUpdateError_mean", cand.Properties.VariableNames)
    sortCols(end + 1) = "relativeFinalUpdateError_mean";
end
if ismember("warmupStepsMean", cand.Properties.VariableNames)
    sortCols(end + 1) = "warmupStepsMean";
end
cand = sortrows(cand, sortCols, repmat("ascend", 1, numel(sortCols)), ...
    "MissingPlacement", "last");
bestRow = cand(1, :);
end

function row = packRow(bestRow, sdef, nFeasible, nCand)
if isempty(bestRow)
    row = {char(sdef.id), char(sdef.methodType), "", "", nan, false, ...
        nan, nan, nan, nan, nan, nan, nan, nan, nFeasible, nCand};
    return;
end
alphaDesign = nan;
if ismember("alphaDesign", bestRow.Properties.VariableNames)
    alphaDesign = bestRow.alphaDesign;
elseif ismember("alpha", bestRow.Properties.VariableNames)
    alphaDesign = bestRow.alpha;
end
feasible = false;
if ismember("feasible", bestRow.Properties.VariableNames)
    feasible = logical(bestRow.feasible);
end
nFail = nan;
if ismember("nSafeStopFail", bestRow.Properties.VariableNames)
    nFail = bestRow.nSafeStopFail;
end
nEval = nan;
if ismember("nEvaluated", bestRow.Properties.VariableNames)
    nEval = bestRow.nEvaluated;
end
stopMae = nan;
if ismember("stopMae_success", bestRow.Properties.VariableNames)
    stopMae = bestRow.stopMae_success;
end
row = {char(sdef.id), char(sdef.methodType), char(bestRow.krMethodKey), char(bestRow.label), ...
    alphaDesign, feasible, bestRow.safeStopRate, ...
    bestRow.finalUpdateMae, bestRow.finalUpdateMae_sem, ...
    bestRow.relativeFinalUpdateError_mean, bestRow.relativeFinalUpdateError_sem, ...
    nFail, nEval, stopMae, nFeasible, nCand};
end

function field = resolveFinalUpdateMaeField(tbl)
field = "";
if ismember("finalUpdateMae_bootMean_b5000", tbl.Properties.VariableNames) ...
        && any(isfinite(tbl.finalUpdateMae_bootMean_b5000))
    field = "finalUpdateMae_bootMean_b5000";
elseif ismember("finalUpdateMae", tbl.Properties.VariableNames) ...
        && any(isfinite(tbl.finalUpdateMae))
    field = "finalUpdateMae";
end
end
