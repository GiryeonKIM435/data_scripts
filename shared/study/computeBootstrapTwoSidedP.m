function p = computeBootstrapTwoSidedP(samples)
%computeBootstrapTwoSidedP ブートストラップ分布から両側p値を算出

s = double(samples(:));
s = s(isfinite(s));
if isempty(s)
    p = nan;
    return;
end

propPos = mean(s >= 0);
propNeg = mean(s <= 0);
p = 2 * min(propPos, propNeg);
p = min(max(p, 0), 1);

end
