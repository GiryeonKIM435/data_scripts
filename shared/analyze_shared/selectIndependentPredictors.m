function [selected, removedLog, corrFinal, vifFinal] = selectIndependentPredictors(tbl, candidatePredictors, cfg)
%selectIndependentPredictors 相関・VIF に基づく説明変数削減

if nargin < 3
    cfg = CvConfig();
end

candidatePredictors = string(candidatePredictors(:)).';
selected = candidatePredictors;
removedLog = struct("removedVariable", {}, "reason", {}, "metric", {}, "value", {});

X = tbl{:, selected};
corrFinal = corrcoef(X, "Rows", "pairwise");

changed = true;
while changed && numel(selected) >= 2
    changed = false;
    C = corrcoef(tbl{:, selected}, "Rows", "pairwise");
    C(logical(eye(size(C)))) = 0;
    [maxVal, linIdx] = max(abs(C(:)));
    if maxVal > cfg.corrThreshold
        [i, j] = ind2sub(size(C), linIdx);
        vifAll = computeVif(tbl, selected);
        if vifAll(j) >= vifAll(i)
            dropName = selected(j);
        else
            dropName = selected(i);
        end
        removedLog(end + 1) = struct("removedVariable", dropName, ...
            "reason", "high correlation", "metric", "|r|", "value", maxVal); %#ok<AGROW>
        selected(selected == dropName) = [];
        changed = true;
    end
end

vifFinal = computeVif(tbl, selected);
while numel(selected) >= 2 && any(vifFinal > cfg.vifThreshold)
    [maxVif, idx] = max(vifFinal);
    dropName = selected(idx);
    removedLog(end + 1) = struct("removedVariable", dropName, ...
        "reason", "high VIF", "metric", "VIF", "value", maxVif); %#ok<AGROW>
    selected(idx) = [];
    vifFinal = computeVif(tbl, selected);
end

if numel(selected) >= 2
    corrFinal = corrcoef(tbl{:, selected}, "Rows", "pairwise");
else
    corrFinal = 1;
end
end

function vif = computeVif(tbl, predNames)
p = numel(predNames);
vif = ones(1, p);
if p < 2
    return;
end
X = double(tbl{:, predNames});
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
            R2 = 1 - ssRes / ssTot;
            if R2 >= 1 - eps
                vif(j) = inf;
            else
                vif(j) = 1 / (1 - R2);
            end
        end
    end
end
end
