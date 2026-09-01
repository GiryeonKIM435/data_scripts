function ci = bootstrapPartialCorr(x, y, Z, B, alpha)
%BOOTSTRAPPARTIALCORR 偏相関のブートストラップ CI

n = numel(y);
ci = [nan, nan];
if n < 5, return; end
boots = nan(B, 1);
for b = 1:B
    idx = randi(n, n, 1);
    try
        boots(b) = partialCorrelation(x(idx), y(idx), Z(idx, :));
    catch
        boots(b) = nan;
    end
end
boots = boots(isfinite(boots));
if isempty(boots), return; end
ci = quantile(boots, [alpha/2, 1-alpha/2]);
end
