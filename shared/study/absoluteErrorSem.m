function sem = absoluteErrorSem(y, yPred)
%absoluteErrorSem 試験片ごとの絶対誤差の SEM（mean |e| の標準誤差）
y = double(y(:));
yPred = double(yPred(:));
mask = isfinite(y) & isfinite(yPred);
absErr = abs(y(mask) - yPred(mask));
sem = continuousSem(absErr);
end
