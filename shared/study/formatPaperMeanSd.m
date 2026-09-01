function s = formatPaperMeanSd(mu, sd, nDec)
%formatPaperMeanSd Mean±SD（小数桁を揃える）

if nargin < 3 || isempty(nDec)
    nDec = 1;
end
s = string(sprintf("%.*f%c%.*f", nDec, mu, char(177), nDec, sd));

end
