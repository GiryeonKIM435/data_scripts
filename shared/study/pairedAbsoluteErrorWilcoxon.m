function pVal = pairedAbsoluteErrorWilcoxon(absA, absB)
%pairedAbsoluteErrorWilcoxon 対応あり絶対誤差の Wilcoxon 符号付順位検定
absA = double(absA(:));
absB = double(absB(:));
if numel(absA) ~= numel(absB) || numel(absA) < 3
    pVal = nan;
    return;
end
mask = isfinite(absA) & isfinite(absB);
absA = absA(mask);
absB = absB(mask);
if numel(absA) < 3
    pVal = nan;
    return;
end
try
    pVal = signrank(absA, absB);
catch
    pVal = nan;
end
end
