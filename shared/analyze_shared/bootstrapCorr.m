function ci = bootstrapCorr(X, y, ctype, B, alpha)
%BOOTSTRAPCORR 単変量相関のブートストラップ CI

[n, p] = size(X);
ci = nan(p, 2);
if n < 4, return; end
boots = zeros(B, p);
for b = 1:B
    idx = randi(n, n, 1);
    Xb = X(idx, :); yb = y(idx);
    valid = all(isfinite(Xb), 2) & isfinite(yb);
    if sum(valid) < 3
        boots(b, :) = nan;
        continue;
    end
    boots(b, :) = corr(Xb(valid, :), yb(valid), "Type", ctype).';
end
loQ = alpha / 2; hiQ = 1 - alpha;
for j = 1:p
    bj = boots(:, j); bj = bj(isfinite(bj));
    if isempty(bj), ci(j, :) = [nan, nan];
    else, ci(j, :) = quantile(bj, [loQ, hiQ]); end
end
end
