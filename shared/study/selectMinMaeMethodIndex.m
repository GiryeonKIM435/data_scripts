function idx = selectMinMaeMethodIndex(innerMae, xi, W)
%selectMinMaeMethodIndex Inner MAE 最小の区間 index（タイブレーク: 小さいξ→小さいW）

innerMae = double(innerMae(:));
xi = double(xi(:));
W = double(W(:));
n = numel(innerMae);
idx = nan;
finite = isfinite(innerMae);
if ~any(finite)
    return;
end
bestMae = min(innerMae(finite));
cand = find(finite & abs(innerMae - bestMae) < 1e-12);
if isempty(cand)
    [~, idx] = min(innerMae);
    return;
end
% 安定タイブレーク
score = xi(cand) * 1e6 + W(cand);
[~, j] = min(score);
idx = cand(j);
if idx < 1 || idx > n
    idx = cand(1);
end
end
