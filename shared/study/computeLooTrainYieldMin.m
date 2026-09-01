function yminTrainAbs = computeLooTrainYieldMin(y)
%computeLooTrainYieldMin LOO 各 fold の訓練セットにおける降伏力最小値 [N]

y = double(y(:));
n = numel(y);
yminTrainAbs = nan(n, 1);
for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    yTr = y(tr);
    yTr = yTr(isfinite(yTr));
    if isempty(yTr)
        continue;
    end
    yminTrainAbs(i) = min(yTr);
end

end
