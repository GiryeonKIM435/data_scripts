function yPred = fitLinearPredict(Xtr, ytr, Xte)
%fitLinearPredict 切片付き線形回帰（OLS）

Xtr = [ones(size(Xtr, 1), 1), Xtr];
Xte = [ones(size(Xte, 1), 1), Xte];
beta = Xtr \ ytr;
yPred = Xte * beta;
end
