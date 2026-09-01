function pairTable = compareMethodsToBestWilcoxon(summaryTable, cvResultsByRow, opts)
%compareMethodsToBestWilcoxon 最良方式 vs 他方式の Wilcoxon + BH
%
% opts.metricField     : summary で最良を選ぶ列（既定 mae_loocv）
% opts.alpha           : online 用（pairTable に alpha 列を付与）
% opts.methodKeyField  : 既定 krMethodKey
% opts.variantField    : 既定 variant（空なら variant 列を無視）
% opts.pairingMode     : "all" | "mutualFinite"（online: 両方有限のみ）

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "metricField") || strlength(string(opts.metricField)) == 0
    opts.metricField = "mae_loocv";
end
if ~isfield(opts, "methodKeyField") || strlength(string(opts.methodKeyField)) == 0
    opts.methodKeyField = "krMethodKey";
end
if ~isfield(opts, "variantField")
    opts.variantField = "variant";
end
if ~isfield(opts, "pairingMode") || strlength(string(opts.pairingMode)) == 0
    opts.pairingMode = "all";
end
if ~isfield(opts, "alpha")
    opts.alpha = nan;
end

pairTable = emptyPairTable(hasAlphaField(opts));
if isempty(summaryTable) || height(summaryTable) == 0
    return;
end

metricField = string(opts.metricField);
if ~ismember(metricField, summaryTable.Properties.VariableNames)
    error("compareMethodsToBestWilcoxon:MissingMetric", ...
        "summaryTable に列がありません: %s", metricField);
end

useVariant = isfield(opts, "variantField") && strlength(string(opts.variantField)) > 0 ...
    && ismember(string(opts.variantField), summaryTable.Properties.VariableNames);

sub = summaryTable;
if isfinite(opts.alpha) && ismember("alpha", sub.Properties.VariableNames)
    sub = sub(sub.alpha == opts.alpha, :);
end
if isempty(sub)
    return;
end

finiteRows = isfinite(sub.(metricField));
if ~any(finiteRows)
    return;
end
subFinite = sub(finiteRows, :);
[~, bestLocalIdx] = min(subFinite.(metricField));
bestRowIdx = find(finiteRows);
bestRowIdx = bestRowIdx(bestLocalIdx);
bestKey = string(sub.(opts.methodKeyField)(bestRowIdx));
bestVariant = "";
if useVariant
    bestVariant = string(sub.(opts.variantField)(bestRowIdx));
end
bestCv = cvResultsByRow{bestRowIdx};

compareIdx = [];
pVals = [];
for ri = 1:height(sub)
    if ri == bestRowIdx
        continue;
    end
    cmpCv = cvResultsByRow{ri};
    [absA, absB, nPaired] = pairedAbsoluteErrors(bestCv, cmpCv, opts.pairingMode);
    if nPaired < 3
        continue;
    end
    pVals(end + 1) = pairedAbsoluteErrorWilcoxon(absA, absB); %#ok<AGROW>
    compareIdx(end + 1) = ri; %#ok<AGROW>
end

if isempty(compareIdx)
    return;
end

fdr = applyBenjaminiHochberg(pVals);
withAlpha = hasAlphaField(opts);
nCols = numel(pairTableColumnNames(withAlpha));
pairRows = cell(0, nCols);
for ii = 1:numel(compareIdx)
    ri = compareIdx(ii);
    cmpKey = string(sub.(opts.methodKeyField)(ri));
    cmpVariant = "";
    if useVariant
        cmpVariant = string(sub.(opts.variantField)(ri));
    end
    cmpCv = cvResultsByRow{ri};
    [absA, absB, nPaired] = pairedAbsoluteErrors(bestCv, cmpCv, opts.pairingMode);
    deltaMae = mean(absA) - mean(absB);
    deltaR2 = nan;
    if isfield(bestCv, "yTrue") && isfield(cmpCv, "yTrue") ...
            && isfield(bestCv, "yPred") && isfield(cmpCv, "yPred")
        yT = bestCv.yTrue(:);
        if isequal(yT, cmpCv.yTrue(:))
            mBest = calcMetrics(yT, bestCv.yPred(:));
            mCmp = calcMetrics(yT, cmpCv.yPred(:));
            deltaR2 = mBest.r2 - mCmp.r2;
        end
    end
    row = {char(bestKey), char(bestVariant), char(cmpKey), char(cmpVariant), ...
        deltaMae, deltaR2, pVals(ii), fdr.qValue(ii), nPaired};
    if withAlpha
        row = [{opts.alpha}, row];
    end
    row = row(:).';
    pairRows(end + 1, :) = row; %#ok<AGROW>
end

pairTable = cell2table(pairRows, 'VariableNames', pairTableColumnNames(withAlpha));
end

function tf = hasAlphaField(opts)
tf = isfield(opts, "alpha") && isfinite(opts.alpha);
end

function tbl = emptyPairTable(withAlpha)
if withAlpha
    tbl = cell2table(cell(0, 10), 'VariableNames', pairTableColumnNames(true));
else
    tbl = cell2table(cell(0, 9), 'VariableNames', pairTableColumnNames(false));
end
end

function names = pairTableColumnNames(withAlpha)
if withAlpha
    names = {'alpha', 'referenceMethod', 'referenceVariant', 'comparisonMethod', ...
        'comparisonVariant', 'deltaMae', 'deltaR2', 'pWilcoxon', 'qValueBH', 'nPaired'};
else
    names = {'referenceMethod', 'referenceVariant', 'comparisonMethod', ...
        'comparisonVariant', 'deltaMae', 'deltaR2', 'pWilcoxon', 'qValueBH', 'nPaired'};
end
end

function [absA, absB, nPaired] = pairedAbsoluteErrors(resA, resB, pairingMode)
absA = [];
absB = [];
nPaired = 0;

if ~isfield(resA, "absErrors") || ~isfield(resB, "absErrors")
    if isfield(resA, "yTrue") && isfield(resA, "yPred") ...
            && isfield(resB, "yTrue") && isfield(resB, "yPred")
        yA = resA.yTrue(:);
        yB = resB.yTrue(:);
        if ~isequal(yA, yB)
            return;
        end
        absA = abs(yA - resA.yPred(:));
        absB = abs(yB - resB.yPred(:));
    else
        return;
    end
else
    absA = resA.absErrors(:);
    absB = resB.absErrors(:);
    if isfield(resA, "ids") && isfield(resB, "ids") ...
            && numel(resA.ids) == numel(absA) && numel(resB.ids) == numel(absB)
        [idsUnion, ia, ib] = intersect(resA.ids(:), resB.ids(:), "stable");
        if isempty(idsUnion)
            return;
        end
        absA = absA(ia);
        absB = absB(ib);
    elseif numel(absA) ~= numel(absB)
        return;
    end
end

if strcmpi(string(pairingMode), "mutualFinite")
    mask = isfinite(absA) & isfinite(absB);
    absA = absA(mask);
    absB = absB(mask);
end
nPaired = numel(absA);
end
