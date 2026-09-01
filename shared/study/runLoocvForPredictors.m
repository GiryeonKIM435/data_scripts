function result = runLoocvForPredictors(tbl, y, predictors)
%runLoocvForPredictors 予測変数セットで LOOCV 実行

predictors = string(predictors(:));
y = double(y(:));

if ~isempty(predictors)
    ok = isfinite(y);
    for pi = 1:numel(predictors)
        ok = ok & isfinite(double(tbl{:, char(predictors(pi))}));
    end
    if ~all(ok)
        tbl = tbl(ok, :);
        y = y(ok);
    end
end

if isempty(predictors)
    cvRes = runInterceptLoocv(y);
elseif numel(predictors) == 1
    X = tbl{:, predictors};
    cvRes = runPairedLoocv(X, y, @(Xtr, ytr, Xte) fitLinearPredict(Xtr, ytr, Xte));
else
    X = tbl{:, predictors};
    cvRes = runPairedLoocv(X, y, @(Xtr, ytr, Xte) predictStandardizedOlsFold(Xtr, ytr, Xte));
end
result = struct();
result.predictors = predictors;
result.cv = cvRes;
result.metrics = cvRes.metrics;
end
