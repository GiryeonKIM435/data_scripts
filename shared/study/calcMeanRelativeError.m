function relErr = calcMeanRelativeError(yTrue, yPred)
%calcMeanRelativeError mean(|yTrue - yPred| / |yTrue|) for yTrue > 0

yTrue = double(yTrue(:));
yPred = double(yPred(:));
mask = isfinite(yTrue) & isfinite(yPred) & (yTrue > 0);
relErr = nan;
if ~any(mask)
    return;
end
relErr = mean(abs(yTrue(mask) - yPred(mask)) ./ abs(yTrue(mask)));

end
