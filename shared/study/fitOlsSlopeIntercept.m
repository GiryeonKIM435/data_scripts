function [a, b] = fitOlsSlopeIntercept(kr, y)
%fitOlsSlopeIntercept F = a*k + b の OLS（切片付き）

kr = double(kr(:));
y = double(y(:));
mask = isfinite(kr) & isfinite(y);
a = nan;
b = nan;
if nnz(mask) < 2
    return;
end
X = [ones(nnz(mask), 1), kr(mask)];
beta = X \ y(mask);
b = beta(1);
a = beta(2);
end
