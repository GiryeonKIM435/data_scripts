function m = calcMetrics(yTrue, yPred)
%calcMetrics R2, MAE, RMSE を計算

yTrue = double(yTrue(:));
yPred = double(yPred(:));
mask = isfinite(yTrue) & isfinite(yPred);
yTrue = yTrue(mask);
yPred = yPred(mask);

m = struct("r2", nan, "mae", nan, "rmse", nan, "n", numel(yTrue));
if isempty(yTrue)
    return;
end

resid = yTrue - yPred;
sse = sum(resid.^2);
sst = sum((yTrue - mean(yTrue)).^2);
if sst > 0
    m.r2 = 1 - sse / sst;
else
    m.r2 = nan;
end
m.mae = mean(abs(resid));
m.rmse = sqrt(mean(resid.^2));
end
