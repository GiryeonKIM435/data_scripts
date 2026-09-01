function res = runPairedLoocv(X, y, fitFn)
%runPairedLoocv LOOCV 評価（各 fold の予測を返す）

y = double(y(:));
n = numel(y);
if isvector(X)
    X = double(X(:));
else
    X = double(X);
end
if size(X, 1) ~= n
    error("runPairedLoocv:SizeMismatch", "X と y の行数が一致しません。");
end

yPred = nan(n, 1);
for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    if size(X, 2) == 1
        Xtr = X(tr);
        Xte = X(i);
    else
        Xtr = X(tr, :);
        Xte = X(i, :);
    end
    yPred(i) = fitFn(Xtr, y(tr), Xte);
end

res = struct();
res.scheme = "LOOCV";
res.n = n;
res.yTrue = y;
res.yPred = yPred;
res.metrics = calcMetrics(y, yPred);
res.residuals = y - yPred;
end
