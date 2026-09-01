function [r, pval] = partialCorrelation(x, y, Z)
%PARTIALCORRELATION 他変数統制後の Pearson 偏相関

mask = isfinite(x) & isfinite(y) & all(isfinite(Z), 2);
xx = x(mask); yy = y(mask);
ZZ = [ones(sum(mask), 1), Z(mask, :)];
if size(ZZ, 1) <= size(ZZ, 2) + 1 || rank(ZZ) < size(ZZ, 2)
    bX = pinv(ZZ) * xx; bY = pinv(ZZ) * yy;
else
    bX = ZZ \ xx; bY = ZZ \ yy;
end
[r, pval] = corr(xx - ZZ * bX, yy - ZZ * bY, "Type", "Pearson");
end
