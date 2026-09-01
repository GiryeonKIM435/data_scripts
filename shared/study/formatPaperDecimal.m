function s = formatPaperDecimal(x, nDec)
%formatPaperDecimal 論文表用の固定小数桁表示

if nargin < 2 || isempty(nDec)
    nDec = 1;
end
if ~isfinite(x)
    s = "";
    return;
end
if nDec <= 0
    s = string(sprintf("%d", round(x)));
else
    s = string(sprintf("%.*f", nDec, x));
end

end
