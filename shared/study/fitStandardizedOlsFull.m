function fit = fitStandardizedOlsFull(X, y)
%fitStandardizedOlsFull 全コホート標準化 OLS（LOOCV fold と同手順）

X = double(X);
y = double(y(:));
mask = all(isfinite(X), 2) & isfinite(y);
X = X(mask, :);
y = y(mask);
n = numel(y);
p = size(X, 2);

fit = struct();
fit.n = n;
fit.predictors = strings(0, 1);
fit.b0 = nan;
fit.betaStd = nan(1, p);
fit.r2_insample = nan;
fit.yHat = nan(n, 1);

if n < p + 2
    return;
end

muX = mean(X, 1);
sigX = std(X, 0, 1);
sigX(sigX == 0) = 1;
muY = mean(y);
sigY = std(y);
if sigY == 0
    sigY = 1;
end

Z = (X - muX) ./ sigX;
yZ = (y - muY) / sigY;
b = [ones(n, 1), Z] \ yZ;
yHatZ = [ones(n, 1), Z] * b;
yHat = yHatZ * sigY + muY;

ssRes = sum((y - yHat).^2);
ssTot = sum((y - mean(y)).^2);
if ssTot > 0
    r2 = 1 - ssRes / ssTot;
else
    r2 = nan;
end

fit.b0 = b(1);
fit.betaStd = b(2:end).';
fit.r2_insample = r2;
fit.yHat = yHat;
fit.muX = muX;
fit.sigX = sigX;
fit.muY = muY;
fit.sigY = sigY;

end
