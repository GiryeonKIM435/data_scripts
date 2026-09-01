function stats = summarizeDeploySafetyMetrics(yTrue, yPred)
%summarizeDeploySafetyMetrics デプロイ予測の安全率指標

yTrue = double(yTrue(:));
yPred = double(yPred(:));
valid = isfinite(yTrue) & isfinite(yPred);
yTrue = yTrue(valid);
yPred = yPred(valid);

stats = struct();
stats.n = numel(yTrue);
if stats.n == 0
    stats.unsafeRate = nan;
    stats.conservativeRate = nan;
    stats.bias = nan;
    stats.safeAt80 = nan;
    stats.safeAt90 = nan;
    stats.safeAt95 = nan;
    stats.medianMarginRatio = nan;
    stats.meanMarginN = nan;
    return;
end

margin = yTrue - yPred;
stats.unsafeRate = mean(yPred > yTrue);
stats.conservativeRate = mean(yPred <= yTrue);
stats.bias = mean(yPred - yTrue);
stats.safeAt80 = mean(yPred <= 0.80 * yTrue);
stats.safeAt90 = mean(yPred <= 0.90 * yTrue);
stats.safeAt95 = mean(yPred <= 0.95 * yTrue);
stats.meanMarginN = mean(margin);
withPosPred = yPred > 0;
if any(withPosPred)
    stats.medianMarginRatio = median(yTrue(withPosPred) ./ yPred(withPosPred));
else
    stats.medianMarginRatio = nan;
end

end
