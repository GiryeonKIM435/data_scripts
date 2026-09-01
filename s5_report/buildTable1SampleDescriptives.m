function bundle = buildTable1SampleDescriptives(cohort, cfg, outDir)
%buildTable1SampleDescriptives 試料記述統計表

% Measured dimensions L1/L2/h, equivalent diameter d_eq, Jeffreys params
% (cM, cK, kK from c1/c2/k2).
vars = ["yieldPointN", "x", "y", "z", "d_eq", "weight", "c1", "c2", "k2"];
labels = ["Bioyield force F_yield [N]", "L1 [mm]", "L2 [mm]", "h [mm]", ...
    "d_eq [mm]", "Weight [g]", "cM [N s/mm]", "cK [N s/mm]", "kK [N/mm]"];
tbl = buildCohortDescriptiveTable(cohort, cfg);

nVar = numel(vars);
varCol = strings(nVar, 1);
meanSdCol = strings(nVar, 1);
minCol = strings(nVar, 1);
maxCol = strings(nVar, 1);

for i = 1:nVar
    v = tbl{:, vars(i)}(:);
    v = v(isfinite(v));
    nDec = paperVarDecimals(vars(i));
    varCol(i) = labels(i);
    meanSdCol(i) = formatPaperMeanSd(mean(v), std(v, 0), nDec);
    minCol(i) = formatPaperDecimal(min(v), nDec);
    maxCol(i) = formatPaperDecimal(max(v), nDec);
end

meanSdColName = "Mean" + string(char(177)) + "SD";
summaryTable = table(varCol, meanSdCol, minCol, maxCol);
summaryTable.Properties.VariableNames = ["Variable", meanSdColName, "Min", "Max"];

basePath = fullfile(outDir, "table1_sample_descriptives");
bundle = exportPaperTableBundle(summaryTable, basePath, ...
    sprintf("Sample descriptives (n=%d)", cohort.n), cfg);
bundle.table = summaryTable;

end
