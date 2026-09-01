function summary = augmentStreamingDeploySummaryWithStopR2(summary, perSample)
%augmentStreamingDeploySummaryWithStopR2 per-sample から finalUpdateR2 を補完

if isempty(summary) || isempty(perSample)
    return;
end
if ismember("finalUpdateR2", summary.Properties.VariableNames)
    if any(isfinite(summary.finalUpdateR2))
        return;
    end
else
    summary.finalUpdateR2 = nan(height(summary), 1);
end

for i = 1:height(summary)
    key = string(summary.krMethodKey(i));
    alpha = summary.alpha(i);
    sub = perSample(string(perSample.krMethodKey) == key ...
        & perSample.alpha == alpha ...
        & isfinite(perSample.finalUpdateErrorN), :);
    if height(sub) < 2
        continue;
    end
    m = calcMetrics(sub.yTrue, sub.y_hat_finalUpdate);
    summary.finalUpdateR2(i) = m.r2;
end

end
