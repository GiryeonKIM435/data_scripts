function completeTable = buildCompleteCohortTable(tbl, gatePredictors)
%BUILDCOMPLETECOHORTTABLE コホート候補: yield + gatePredictors がすべて有限な試料

gatePredictors = string(gatePredictors(:));
colNames = string(tbl.Properties.VariableNames);

if ~ismember("yieldPointN", colNames)
    error("buildCompleteCohortTable:MissingTarget", "master に yieldPointN 列がありません。");
end

finiteMask = isfinite(tbl.yieldPointN);
for i = 1:numel(gatePredictors)
    p = gatePredictors(i);
    if ~ismember(p, colNames)
        error("buildCompleteCohortTable:MissingColumn", ...
            "master に列がありません: %s。run_build_master_table を実行してください。", p);
    end
    finiteMask = finiteMask & isfinite(tbl{:, p});
end

completeTable = tbl(finiteMask, :);

end
