function [yDisplay, thrDisplay, thrIdx] = prepareQ3DeployStopDisplay(yHat, alpha, tStop)
%prepareQ3DeployStopDisplay Stop 以降は ŷ を停止時予測値で保持、閾値は Stop まで

yHat = yHat(:);
T = numel(yHat);
alpha = double(alpha);
tStop = double(tStop);

yDisplay = yHat;
thrDisplay = yHat ./ alpha;
thrIdx = (1:T)';

if ~(isfinite(tStop) && tStop >= 1 && tStop <= T)
    return;
end

tStop = round(tStop);
yFinal = yHat(tStop);
if ~isfinite(yFinal)
    prior = find(isfinite(yHat(1:tStop)), 1, "last");
    if ~isempty(prior)
        yFinal = yHat(prior);
    end
end
if isfinite(yFinal)
    yDisplay(tStop + 1:end) = yFinal;
end

thrIdx = (1:tStop)';

end
