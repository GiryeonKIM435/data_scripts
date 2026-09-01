function sem = relativeErrorSem(y, yPred)
%relativeErrorSem 試験片ごとの相対誤差の SEM
y = double(y(:));
yPred = double(yPred(:));
mask = isfinite(y) & isfinite(yPred) & (y ~= 0);
if ~any(mask)
    sem = nan;
    return;
end
relErr = abs(y(mask) - yPred(mask)) ./ abs(y(mask));
sem = continuousSem(relErr);
end
