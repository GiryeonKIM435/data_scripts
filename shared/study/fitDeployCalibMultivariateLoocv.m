function calib = fitDeployCalibMultivariateLoocv(tbl, y, predictors, krCol)
%fitDeployCalibMultivariateLoocv 標準化 OLS の LOO キャリブ（デプロイ用）

predictors = string(predictors(:));
if nargin < 4 || isempty(krCol) || strlength(string(krCol)) == 0
    krCol = predictors(1);
else
    krCol = string(krCol);
end
y = double(y(:));
n = numel(y);
X = tbl{:, cellstr(predictors)};

calib = struct();
calib.type = "multivariate";
calib.predictors = predictors;
calib.krCol = krCol;
calib.n = n;
calib.muX = nan(n, numel(predictors));
calib.sigX = nan(n, numel(predictors));
calib.muY = nan(n, 1);
calib.sigY = nan(n, 1);
calib.b0 = nan(n, 1);
calib.beta = nan(n, numel(predictors));
calib.nValid = 0;

for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    Xtr = X(tr, :);
    ytr = y(tr);
    validTr = all(isfinite(Xtr), 2) & isfinite(ytr);
    if nnz(validTr) < numel(predictors) + 2
        continue;
    end
    Xtr = Xtr(validTr, :);
    ytr = ytr(validTr);
    Xte = X(i, :);
    if any(~isfinite(Xte))
        continue;
    end
    [~, stats] = fitStandardizedOlsFoldStats(Xtr, ytr, Xte);
    calib.muX(i, :) = stats.muX;
    calib.sigX(i, :) = stats.sigX;
    calib.muY(i) = stats.muY;
    calib.sigY(i) = stats.sigY;
    calib.b0(i) = stats.b0;
    calib.beta(i, :) = stats.beta(:).';
    calib.nValid = calib.nValid + 1;
end

end

function [yPred, stats] = fitStandardizedOlsFoldStats(Xtr, ytr, Xte)
muX = mean(Xtr, 1);
sigX = std(Xtr, 0, 1);
sigX(sigX == 0) = 1;
muY = mean(ytr);
sigY = std(ytr);
if sigY == 0
    sigY = 1;
end
Ztr = (Xtr - muX) ./ sigX;
Zte = (Xte - muX) ./ sigX;
ytrZ = (ytr - muY) / sigY;
b = [ones(size(Ztr, 1), 1), Ztr] \ ytrZ;
yPredZ = [1, Zte] * b;
yPred = yPredZ * sigY + muY;
stats = struct("muX", muX, "sigX", sigX, "muY", muY, "sigY", sigY, ...
    "b0", b(1), "beta", b(2:end));
end
