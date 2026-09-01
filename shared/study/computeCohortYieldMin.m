function yminCohortAbs = computeCohortYieldMin(y)
%computeCohortYieldMin コホート全試料の真降伏力最小値 [N]（全試料共通スカラー）

y = double(y(:));
y = y(isfinite(y));
if isempty(y)
    error("computeCohortYieldMin:EmptyCohort", ...
        "有限な降伏力が 1 件もありません。");
end
yminCohortAbs = min(y);

end
