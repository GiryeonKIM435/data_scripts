function ci = bootstrapLoocvMetricCi(y, yPred, metricName, cfg, seedOffset)
%bootstrapLoocvMetricCi LOOCV 予測の bootstrap 95% CI（mae/rmse/r2）
%
% seedOffset（任意）: 並列 worker ごとに乱数系列を分離（グローバル rng 競合回避）

if nargin < 4 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 5 || isempty(seedOffset)
    seedOffset = 0;
end

y = double(y(:));
yPred = double(yPred(:));
n = numel(y);
B = cfg.cv.bootstrapSamples;
stream = RandStream("twister", "Seed", cfg.cv.bootstrapSeed + double(seedOffset));

bootVals = nan(B, 1);
for b = 1:B
    idx = randi(stream, n, n, 1);
    bootVals(b) = bootstrapMetricValue(y(idx), yPred(idx), metricName);
end

ci = struct();
ci.metric = string(metricName);
ci.lo = quantile(bootVals, 0.025);
ci.hi = quantile(bootVals, 0.975);
ci.median = median(bootVals, "omitnan");
ci.samples = bootVals;
end

function v = bootstrapMetricValue(y, yPred, metricName)
switch string(metricName)
    case "relativeError"
        v = calcMeanRelativeError(y, yPred);
    otherwise
        m = calcMetrics(y, yPred);
        v = metricValueFromStruct(m, metricName);
end
end

function v = metricValueFromStruct(m, metricName)
switch string(metricName)
    case "mae"
        v = m.mae;
    case "rmse"
        v = m.rmse;
    case "r2"
        v = m.r2;
    otherwise
        error("bootstrapLoocvMetricCi:BadMetric", "未知の metric: %s", metricName);
end
end
