function [alpha, ep] = computeDesignAlphaFromTrain(krTrain, yTrain, a, b, quantileP, gamma)
%computeDesignAlphaFromTrain 訓練集合当てはめ過大推定から α_{0.95} を算出
%
% 現行 Q7 と同式: e_j = max(0, (a*k_j+b - y_j)/|y_j|) の p 分位点 ep について
% alpha = (1 + ep) * gamma。訓練点のみを用い、検証/テスト点は含めない。

if nargin < 5 || isempty(quantileP)
    quantileP = 0.95;
end
if nargin < 6 || isempty(gamma)
    gamma = 1;
end

krTrain = double(krTrain(:));
yTrain = double(yTrain(:));
alpha = nan;
ep = nan;
if ~(isfinite(a) && isfinite(b))
    return;
end

eTrain = nan(numel(yTrain), 1);
for j = 1:numel(yTrain)
    if ~(isfinite(krTrain(j)) && isfinite(yTrain(j)) && abs(yTrain(j)) > 0)
        continue;
    end
    yHat = b + a * krTrain(j);
    if ~isfinite(yHat)
        continue;
    end
    eTrain(j) = max(0, (yHat - yTrain(j)) / abs(yTrain(j)));
end
epVals = eTrain(isfinite(eTrain));
if isempty(epVals)
    return;
end
ep = quantile(epVals, quantileP);
alpha = (1 + ep) * gamma;
end
