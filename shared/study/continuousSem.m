function sem = continuousSem(x)
%continuousSem 連続値ベクトルの SEM（標本標準偏差 / sqrt(n)）
n = numel(x);
if n <= 1
    sem = nan;
    return;
end
sem = std(x, 0) / sqrt(n);
end
