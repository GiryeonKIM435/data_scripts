function foldTbl = collectCvFoldCoefficients(tbl, y, predictors)
%collectCvFoldCoefficients LOOCV fold ごとの標準化 OLS 係数

predictors = string(predictors(:));
y = double(y(:));
X = tbl{:, predictors};
n = numel(y);
p = numel(predictors);
betaMat = nan(n, p);

for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    Xtr = X(tr, :);
    ytr = y(tr);
    Xte = X(i, :);
    [~, betaStd] = predictStandardizedOlsFold(Xtr, ytr, Xte);
    betaMat(i, :) = betaStd(:).';
end

foldTbl = array2table(betaMat, 'VariableNames', cellstr(predictors));
foldTbl.foldIdx = (1:n).';
foldTbl = movevars(foldTbl, "foldIdx", "Before", predictors(1));
end
