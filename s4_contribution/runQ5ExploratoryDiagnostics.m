function diag = runQ5ExploratoryDiagnostics(cohort, modelCases, cfg, outDir, krCol)
%runQ5ExploratoryDiagnostics ピアソン相関・VIF・探索的診断（LOOCV前削減なし）

if nargin < 5
    krCol = "";
end
krCol = string(krCol);

tbl = cohort.predictorTable;
y = cohort.y;
cvCfg = makeQ5CollinearityCfg(cfg);

globalPool = unique([krCol; "weight"; "d_eq"; cfg.burgersPredictors(:)], "stable");
globalPool = globalPool(ismember(globalPool, string(tbl.Properties.VariableNames)));

[corrMatFixed, corrLabelsFixed] = buildQ5FixedCorrMatrix(tbl, y, krCol);
writetable(corrMatFixed, fullfile(outDir, "corr_matrix_predictors.csv"));

pearsonRows = cell(numel(globalPool), 4);
for pi = 1:numel(globalPool)
    p = globalPool(pi);
    x = tbl{:, char(p)};
    mask = isfinite(x) & isfinite(y);
    if nnz(mask) < 3
        r = nan;
        pval = nan;
    else
        [R, P] = corrcoef(x(mask), y(mask));
        r = R(1, 2);
        pval = P(1, 2);
    end
    pearsonRows(pi, :) = {char(p), r, pval, cohort.n};
end
pearsonTable = cell2table(pearsonRows, 'VariableNames', ...
    {'predictor', 'pearsonR_vsYield', 'pearsonP', 'n'});

if numel(globalPool) >= 2
    labels = [string("yieldPointN"); string(globalPool(:))];
    varNames = cellstr(labels.');
    corrMat = array2table(corr([y, tbl{:, cellstr(globalPool)}], "Rows", "pairwise"), ...
        'VariableNames', varNames);
else
    corrMat = table();
end
writetable(corrMat, fullfile(outDir, "corr_matrix_initial.csv"));

vifInit = computeQ5VifTable(tbl, globalPool);
vifGlobalRows = cell(height(vifInit), 3);
for vi = 1:height(vifInit)
    vifGlobalRows(vi, :) = {char(vifInit.predictor(vi)), vifInit.vif(vi), "global_pool"};
end
vifGlobalTable = cell2table(vifGlobalRows, 'VariableNames', ...
    {'predictor', 'vif', 'scope'});

caseReduced = struct("caseId", {}, "modelId", {}, "candidates", {}, "selected", {}, ...
    "protectedPredictors", {}, "collinearityMode", {}, "removedLog", {}, "vifFinal", {});

vifRows = {};
for ci = 1:numel(modelCases)
    caseDef = modelCases(ci);
    cands = caseDef.candidates;
    cands = cands(ismember(cands, string(tbl.Properties.VariableNames)));
    vifInitCase = computeQ5VifTable(tbl, cands);
    for vi = 1:height(vifInitCase)
        vifRows(end + 1, :) = {char(caseDef.caseId), char(vifInitCase.predictor(vi)), ...
            vifInitCase.vif(vi), "descriptive_initial"}; %#ok<AGROW>
    end

    caseReduced(ci).caseId = caseDef.caseId;
    caseReduced(ci).modelId = caseDef.modelId;
    caseReduced(ci).candidates = cands;
    caseReduced(ci).selected = cands;
    caseReduced(ci).protectedPredictors = caseDef.protectedPredictors;
    caseReduced(ci).collinearityMode = caseDef.collinearityMode;
    caseReduced(ci).removedLog = struct("removedVariable", {}, "reason", {}, "metric", {}, "value", {});
    vifFinTbl = table(cands(:), computeQ5VifTable(tbl, cands).vif(:), ...
        'VariableNames', {'predictor', 'vif'});
    caseReduced(ci).vifFinal = vifFinTbl;
end

vifTable = cell2table(vifRows, 'VariableNames', ...
    {'caseId', 'predictor', 'vif', 'stage'});
removedTable = table(string.empty, string.empty, string.empty, string.empty, double.empty, ...
    'VariableNames', {'caseId', 'removedVariable', 'reason', 'metric', 'value'});

writetable(pearsonTable, fullfile(outDir, "pearson_vs_yield.csv"));
writetable(vifTable, fullfile(outDir, "vif_by_case.csv"));
writetable(vifGlobalTable, fullfile(outDir, "vif_global_pool.csv"));
writetable(removedTable, fullfile(outDir, "collinearity_removed_log.csv"));

diagGlobal = table(globalPool, pearsonTable.pearsonR_vsYield, pearsonTable.pearsonP, vifInit.vif, ...
    'VariableNames', {'predictor', 'pearsonR_vsYield', 'pearsonP', 'vif'});
writetable(diagGlobal, fullfile(outDir, "diagnostics_global.csv"));

diag = struct();
diag.pearsonTable = pearsonTable;
diag.corrMatrixInitial = corrMat;
diag.corrMatrixFixed = corrMatFixed;
diag.corrLabelsFixed = corrLabelsFixed;
diag.vifTable = vifTable;
diag.vifGlobalTable = vifGlobalTable;
diag.removedTable = removedTable;
diag.diagnosticsGlobal = diagGlobal;
diag.caseReduced = caseReduced;

end

function [corrTbl, labels] = buildQ5FixedCorrMatrix(tbl, y, krCol)
labels = ["yieldPointN", "kr", "k2", "c1", "c2", "d_eq", "weight"];
tblCols = string(["k2", "c1", "c2", "d_eq", "weight"]);
dataCols = strings(1, numel(labels));
dataCols(1) = "yieldPointN";
dataCols(2) = krCol;
for i = 3:numel(labels)
    col = tblCols(i - 2);
    if ismember(col, string(tbl.Properties.VariableNames))
        dataCols(i) = col;
    else
        dataCols(i) = missing;
    end
end

mat = nan(numel(labels), numel(labels));
for i = 1:numel(labels)
    for j = 1:numel(labels)
        if i == j
            mat(i, j) = 1;
            continue;
        end
        if ismissing(dataCols(i)) || ismissing(dataCols(j))
            continue;
        end
        if i == 1
            xi = y(:);
        else
            xi = tbl{:, char(dataCols(i))};
        end
        if j == 1
            xj = y(:);
        else
            xj = tbl{:, char(dataCols(j))};
        end
        mask = isfinite(xi) & isfinite(xj);
        if nnz(mask) < 3
            continue;
        end
        R = corrcoef(xi(mask), xj(mask));
        mat(i, j) = R(1, 2);
    end
end

corrTbl = array2table(mat, 'VariableNames', cellstr(labels), 'RowNames', cellstr(labels));
end

function vifTbl = computeQ5VifTable(tbl, predictors)
predictors = string(predictors(:));
vifVals = nan(numel(predictors), 1);
for i = 1:numel(predictors)
    others = setdiff(predictors, predictors(i));
    if isempty(others)
        vifVals(i) = 1;
    else
        Xo = tbl{:, cellstr(others)};
        xi = tbl{:, char(predictors(i))};
        mdl = fitlm(Xo, xi);
        r2 = mdl.Rsquared.Ordinary;
        if r2 >= 1
            vifVals(i) = inf;
        else
            vifVals(i) = 1 / (1 - r2);
        end
    end
end
vifTbl = table(predictors, vifVals, 'VariableNames', {'predictor', 'vif'});
end
