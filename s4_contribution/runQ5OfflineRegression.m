function offline = runQ5OfflineRegression(cohort, caseReduced, cfg, outDir, krCol)
%runQ5OfflineRegression ケース別重回帰 LOOCV

tbl = cohort.predictorTable;
y = cohort.y;
colCfg = makeQ5CollinearityCfg(cfg);
modelResults = struct("caseId", {}, "name", {}, "predictors", {}, "cv", {}, ...
    "metrics", {}, "coefTable", {}, "fullFit", {}, "foldSelected", {}, "foldRemovedLog", {});
scatterData = struct("caseId", {}, "yTrue", {}, "yPred", {}, "metrics", {});
compareRows = {};

summaryRows = cell(numel(caseReduced), 6);
for ci = 1:numel(caseReduced)
    cr = caseReduced(ci);
    preds = cr.selected;
    if isempty(preds)
        warning("runQ5OfflineRegression:EmptyCase", "case %s: predictor なし", cr.caseId);
        continue;
    end
    modelName = char(cr.caseId);
    modelDef = struct( ...
        "name", modelName, ...
        "predictors", preds, ...
        "collinearityMode", cr.collinearityMode, ...
        "protectedPredictors", cr.protectedPredictors, ...
        "collinearityCfg", colCfg);
    bundle = runNestedLoocvModels(tbl, y, modelDef, cfg);
    mr = bundle.modelResults(1);
    coefTbl = collectCvFoldCoefficients(tbl, y, preds);
    writetable(coefTbl, fullfile(outDir, "offline_coefficients_" + cr.caseId + ".csv"));

    if isfield(mr, "foldSelected")
        writeFoldCollinearityLog(outDir, cr.caseId, mr.foldSelected, mr.foldRemovedLog);
    end

    X = tbl{:, cellstr(preds)};
    fullFit = fitStandardizedOlsFull(X, y);
    fullFit.predictors = preds;

    modelResults(ci).caseId = cr.caseId;
    modelResults(ci).name = cr.caseId;
    modelResults(ci).predictors = preds;
    modelResults(ci).cv = mr.cv;
    modelResults(ci).metrics = mr.metrics;
    modelResults(ci).coefTable = coefTbl;
    modelResults(ci).fullFit = fullFit;
    if isfield(mr, "foldSelected")
        modelResults(ci).foldSelected = mr.foldSelected;
        modelResults(ci).foldRemovedLog = mr.foldRemovedLog;
    end

    scatterData(ci).caseId = cr.caseId;
    scatterData(ci).yTrue = mr.cv.yTrue;
    scatterData(ci).yPred = mr.cv.yPred;
    scatterData(ci).metrics = mr.metrics;

    betaParts = strings(1, numel(preds));
    for pi = 1:numel(preds)
        pName = preds(pi);
        if numel(fullFit.betaStd) >= pi && isfinite(fullFit.betaStd(pi))
            betaParts(pi) = sprintf("%s=%.3f", pName, fullFit.betaStd(pi));
        else
            betaParts(pi) = sprintf("%s=NA", pName);
        end
    end
    compareRows(end + 1, :) = {char(cr.caseId), char(strjoin(preds, "|")), ...
        mr.metrics.r2, mr.metrics.mae, char(strjoin(betaParts, ", "))}; %#ok<AGROW>

    summaryRows(ci, :) = {char(cr.caseId), char(strjoin(preds, "|")), ...
        mr.metrics.r2, mr.metrics.mae, mr.metrics.rmse, cohort.n};
end

summaryTable = cell2table(summaryRows, 'VariableNames', ...
    {'caseId', 'predictors', 'r2_loocv', 'mae_loocv', 'rmse_loocv', 'n'});
writetable(summaryTable, fullfile(outDir, "offline_loocv_summary.csv"));

if isempty(compareRows)
    modelCompareTable = table(string.empty, string.empty, double.empty, double.empty, string.empty, ...
        'VariableNames', {'caseId', 'predictors', 'r2_loocv', 'mae_loocv', 'beta_std_summary'});
else
    modelCompareTable = cell2table(compareRows, 'VariableNames', ...
        {'caseId', 'predictors', 'r2_loocv', 'mae_loocv', 'beta_std_summary'});
end
writetable(modelCompareTable, fullfile(outDir, "offline_model_compare.csv"));

offline = struct();
offline.modelResults = modelResults;
offline.summaryTable = summaryTable;
offline.scatterData = scatterData;
offline.modelCompareTable = modelCompareTable;

end

function writeFoldCollinearityLog(outDir, caseId, foldSelected, foldRemovedLog)
rows = {};
for fi = 1:numel(foldSelected)
    sel = string(foldSelected{fi});
    removed = foldRemovedLog{fi};
    if isempty(removed)
        rows(end + 1, :) = {char(caseId), fi, char(strjoin(sel, "|")), "", "", nan}; %#ok<AGROW>
        continue;
    end
    for ri = 1:numel(removed)
        rows(end + 1, :) = {char(caseId), fi, char(strjoin(sel, "|")), ...
            char(removed(ri).removedVariable), char(removed(ri).reason), removed(ri).value}; %#ok<AGROW>
    end
end
if isempty(rows)
    return;
end
tbl = cell2table(rows, 'VariableNames', ...
    {'caseId', 'foldIdx', 'selectedPredictors', 'removedVariable', 'reason', 'metricValue'});
writetable(tbl, fullfile(outDir, "fold_collinearity_" + caseId + ".csv"));
end
