function [yPred, betaStd] = predictStandardizedOlsFold(Xtr, ytr, Xte)
%predictStandardizedOlsFold LOOCV fold 内標準化 OLS 予測（係数オプション）

muX = mean(Xtr, 1);
sigX = std(Xtr, 0, 1);
sigX(sigX == 0) = 1;
muY = mean(ytr);
sigY = std(ytr);
if sigY == 0
    sigY = 1;
end
Ztr = (Xtr - muX) ./ sigX;
Zte = (Xte - muX) ./ sigX;
ytrZ = (ytr - muY) / sigY;
b = [ones(size(Ztr, 1), 1), Ztr] \ ytrZ;
yPredZ = [ones(size(Zte, 1), 1), Zte] * b;
yPred = yPredZ * sigY + muY;
if nargout > 1
    betaStd = b(2:end);
end
end
