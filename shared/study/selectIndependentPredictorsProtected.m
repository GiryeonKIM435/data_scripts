function [selected, removedLog, corrFinal, vifFinal] = selectIndependentPredictorsProtected( ...
    tbl, candidatePredictors, cfg, protectedVars)
%selectIndependentPredictorsProtected 保護変数を除いて共線性削減

if nargin < 4
    protectedVars = string.empty(0, 1);
end
protectedVars = string(protectedVars(:));
candidatePredictors = string(candidatePredictors(:)).';

protectedPresent = intersect(candidatePredictors, protectedVars, "stable");
reducible = setdiff(candidatePredictors, protectedPresent, "stable");

if isempty(reducible)
    selected = protectedPresent;
    removedLog = struct("removedVariable", {}, "reason", {}, "metric", {}, "value", {});
    if numel(selected) >= 2
        corrFinal = corrcoef(tbl{:, cellstr(selected)}, "Rows", "pairwise");
        vifFinal = computeProtectedVif(tbl, selected);
    else
        corrFinal = 1;
        vifFinal = 1;
    end
    return;
end

[reduced, removedLog, corrFinal, vifFinal] = selectIndependentPredictors(tbl, reducible, cfg);
selected = [protectedPresent(:); reduced(:)];
selected = unique(selected, "stable");

if numel(selected) >= 2
    corrFinal = corrcoef(tbl{:, cellstr(selected)}, "Rows", "pairwise");
    vifFinal = computeProtectedVif(tbl, selected);
elseif numel(selected) == 1
    corrFinal = 1;
    vifFinal = 1;
end
end

function vif = computeProtectedVif(tbl, predNames)
predNames = string(predNames(:));
p = numel(predNames);
vif = ones(1, p);
if p < 2
    return;
end
X = double(tbl{:, cellstr(predNames)});
ok = all(isfinite(X), 2);
X = X(ok, :);
if size(X, 1) < (p + 1)
    vif(:) = inf;
    return;
end
for j = 1:p
    yj = X(:, j);
    Xo = X(:, setdiff(1:p, j));
    Xo = [ones(size(Xo, 1), 1), Xo];
    if rank(Xo) < size(Xo, 2)
        vif(j) = inf;
    else
        b = Xo \ yj;
        yhat = Xo * b;
        ssRes = sum((yj - yhat).^2);
        ssTot = sum((yj - mean(yj)).^2);
        if ssTot <= eps
            vif(j) = 1;
        else
            r2 = 1 - ssRes / ssTot;
            if r2 >= 1 - eps
                vif(j) = inf;
            else
                vif(j) = 1 / (1 - r2);
            end
        end
    end
end
end
