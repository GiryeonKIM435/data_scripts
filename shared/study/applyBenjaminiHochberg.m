function out = applyBenjaminiHochberg(pValues, alpha)
%applyBenjaminiHochberg Benjamini-Hochberg FDR 補正

pValues = double(pValues(:));
m = numel(pValues);
if nargin < 2 || isempty(alpha)
    alpha = 0.05;
end

out = struct();
out.pRaw = pValues;
out.qValue = nan(m, 1);
out.reject = false(m, 1);

valid = isfinite(pValues);
if ~any(valid)
    return;
end

p = pValues(valid);
[sortedP, ord] = sort(p);
ranks = (1:numel(sortedP)).';
qSorted = sortedP .* m ./ ranks;
for i = numel(qSorted)-1:-1:1
    qSorted(i) = min(qSorted(i), qSorted(i + 1));
end
q = nan(size(p));
q(ord) = qSorted;
out.qValue(valid) = min(q, 1);
out.reject(valid) = out.qValue(valid) <= alpha;
end
