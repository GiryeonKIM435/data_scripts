function tblOut = compareModelsToReference(modelResults, refName, cfg, comparisonType)
%compareModelsToReference 参照モデルとのペア LOOCV 比較表

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 4 || isempty(comparisonType)
    comparisonType = "generic";
end

refIdx = findModelIndex(modelResults, refName);
ref = modelResults(refIdx);
rows = cell(0, 21);
pVals = [];

for mi = 1:numel(modelResults)
    if mi == refIdx
        continue;
    end
    cmp = modelResults(mi);
    stats = pairedResidualTest(cmp.cv, ref.cv, cfg);
    summ = summarizePairedCvComparison(cmp.cv, ref.cv, cfg, ...
        struct("modelA", cmp.name, "modelB", ref.name));
    pVals(end + 1) = stats.pWilcoxonMae; %#ok<AGROW>
    rows(end + 1, :) = {char(cmp.name), char(ref.name), char(comparisonType), ...
        cmp.metrics.mae, ref.metrics.mae, stats.deltaMae, ...
        stats.ciDeltaMae(1), stats.ciDeltaMae(2), stats.pBootstrapMae, ...
        stats.pWilcoxonMae, summ.winRateA, summ.cohenDz, ...
        summ.pWilcoxonOneSidedImproveA, ...
        stats.meanMaeA, stats.ciMeanMaeA(1), stats.ciMeanMaeA(2), ...
        stats.meanMaeB, stats.ciMeanMaeB(1), stats.ciMeanMaeB(2), ...
        stats.pBootstrapMeanComparison, stats.isMeanCiSeparated}; %#ok<AGROW>
end

tblOut = cell2table(rows, 'VariableNames', { ...
    'model', 'referenceModel', 'comparisonType', ...
    'maeModel', 'maeReference', 'deltaMae', ...
    'ciDeltaMaeLo', 'ciDeltaMaeHi', 'pBootstrap', 'pWilcoxon', ...
    'winRateModel', 'cohenDz', 'pWilcoxonOneSidedImprove', ...
    'meanMaeModel', 'ciMeanMaeModelLo', 'ciMeanMaeModelHi', ...
    'meanMaeReference', 'ciMeanMaeReferenceLo', 'ciMeanMaeReferenceHi', ...
    'pBootstrapMeanCompare', 'isMeanCiSeparated'});

if ~isempty(pVals)
    fdr = applyBenjaminiHochberg(pVals);
    tblOut.qValueBH = fdr.qValue(:);
else
    tblOut.qValueBH = double.empty(0, 1);
end
end

function idx = findModelIndex(modelResults, modelName)
names = string({modelResults.name});
idx = find(names == string(modelName), 1);
if isempty(idx)
    error("compareModelsToReference:MissingModel", "モデルが見つかりません: %s", modelName);
end
end
