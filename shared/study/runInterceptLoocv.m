function cvRes = runInterceptLoocv(y)
%runInterceptLoocv 切片のみ LOOCV

n = numel(y);
yPred = nan(n, 1);
for i = 1:n
    yPred(i) = mean(y(setdiff(1:n, i)));
end
cvRes = struct();
cvRes.scheme = "LOOCV";
cvRes.yTrue = y(:);
cvRes.yPred = yPred;
cvRes.metrics = calcMetrics(y, yPred);
cvRes.residuals = y(:) - yPred;
cvRes.n = n;
end
