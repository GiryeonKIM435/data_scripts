function pairTable = compareStreamingDeployMethodsToBest(perSampleTable, summaryTable, alphaValues)
%compareStreamingDeployMethodsToBest α ごとに Final-update MAE 最良 vs 他方式 Wilcoxon+BH

pairTable = emptyStreamingPairTable();
if isempty(perSampleTable) || isempty(summaryTable)
    return;
end

alphaValues = alphaValues(:);
allRows = cell(0, numel(pairTableColumnNames()));

for ai = 1:numel(alphaValues)
    alpha = alphaValues(ai);
    sub = summaryTable(summaryTable.alpha == alpha, :);
    if isempty(sub)
        continue;
    end

    metricField = "finalUpdateMae";
    if ~ismember("finalUpdateMae", sub.Properties.VariableNames)
        metricField = "stopMae_success";
    end
    finiteRows = isfinite(sub.(metricField));
    if ~any(finiteRows)
        continue;
    end
    subFinite = sub(finiteRows, :);
    [~, bestLocalIdx] = min(subFinite.(metricField));
    bestRowIdx = find(finiteRows);
    bestRowIdx = bestRowIdx(bestLocalIdx);
    bestKey = string(sub.krMethodKey(bestRowIdx));

    cvByRow = buildStreamingDeployCvResults(perSampleTable, sub, alpha);
    bestCv = cvByRow{bestRowIdx};

    compareIdx = [];
    pVals = [];
    deltaMaeVals = [];
    nPairedVals = [];
    for ri = 1:height(sub)
        if ri == bestRowIdx
            continue;
        end
        cmpCv = cvByRow{ri};
        [absBest, absCmp, nPaired] = pairMutualErrors(bestCv, cmpCv);
        if nPaired < 3
            continue;
        end
        pVal = pairedAbsoluteErrorWilcoxon(absBest, absCmp);
        compareIdx(end + 1, 1) = ri; %#ok<AGROW>
        pVals(end + 1, 1) = pVal; %#ok<AGROW>
        deltaMaeVals(end + 1, 1) = mean(absBest) - mean(absCmp); %#ok<AGROW>
        nPairedVals(end + 1, 1) = nPaired; %#ok<AGROW>
    end

    if isempty(compareIdx)
        continue;
    end
    fdr = applyBenjaminiHochberg(pVals);
    for ii = 1:numel(compareIdx)
        ri = compareIdx(ii);
        row = {alpha, char(bestKey), "", char(string(sub.krMethodKey(ri))), "", ...
            deltaMaeVals(ii), nan, nan, pVals(ii), fdr.qValue(ii), nPairedVals(ii)};
        allRows(end + 1, :) = row; %#ok<AGROW>
    end
end

if isempty(allRows)
    return;
end
pairTable = cell2table(allRows, 'VariableNames', pairTableColumnNames());
end

function tbl = emptyStreamingPairTable()
tbl = cell2table(cell(0, 11), 'VariableNames', pairTableColumnNames());
end

function names = pairTableColumnNames()
% pWilcoxon を主列とし、後方互換のため pBootstrap 同義列名は使わない
names = {'alpha', 'referenceMethod', 'referenceVariant', 'comparisonMethod', ...
    'comparisonVariant', 'deltaMae', 'deltaMaeCiLo', 'deltaMaeCiHi', ...
    'pWilcoxon', 'qValueBH', 'nPaired'};
end

function [absBest, absCmp, nPaired] = pairMutualErrors(bestCv, cmpCv)
absBest = [];
absCmp = [];
nPaired = 0;
if ~isfield(bestCv, "absErrors") || ~isfield(cmpCv, "absErrors")
    return;
end
if ~isfield(bestCv, "ids") || ~isfield(cmpCv, "ids")
    return;
end
[idsCommon, ia, ib] = intersect(bestCv.ids(:), cmpCv.ids(:), "stable");
if isempty(idsCommon)
    return;
end
absBest = bestCv.absErrors(ia);
absCmp = cmpCv.absErrors(ib);
mask = isfinite(absBest) & isfinite(absCmp);
absBest = absBest(mask);
absCmp = absCmp(mask);
nPaired = numel(absBest);
end
