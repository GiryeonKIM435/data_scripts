function [perSampleTable, summaryTable] = augmentQ7OnlineSafetyMetrics(perSampleTable, summaryTable)
%augmentQ7OnlineSafetyMetrics utilization / failure rate / stopping margin を付与
%
% 既存列（F_used, F_stop, yTrue, outcome, safeStopRate）から論文用安全性指標を集計する。
%   utilization     = F_used / F_yield（成功例）
%   stoppingMargin  = (F_yield - F_stop) / F_yield（成功例）
%   stopForceRatio  = F_stop / F_yield（成功例）
%   failureRate     = 1 - safeStopRate（区間ごと）

if isempty(perSampleTable)
    return;
end

if ~ismember("F_used", perSampleTable.Properties.VariableNames)
    error("augmentQ7OnlineSafetyMetrics:MissingFused", ...
        "perSampleTable に F_used 列がありません。Q7 を再実行してください（doOnline, reuseExistingResults=false）。");
end
if ~ismember("F_stop", perSampleTable.Properties.VariableNames)
    error("augmentQ7OnlineSafetyMetrics:MissingFstop", ...
        "perSampleTable に F_stop 列がありません。");
end

isSuccess = string(perSampleTable.outcome) == "success";
yAbs = abs(perSampleTable.yTrue);
okY = isfinite(perSampleTable.yTrue) & (yAbs > 0);

util = nan(height(perSampleTable), 1);
okU = isSuccess & okY & isfinite(perSampleTable.F_used);
util(okU) = perSampleTable.F_used(okU) ./ yAbs(okU);
perSampleTable.utilization = util;

margin = nan(height(perSampleTable), 1);
ratio = nan(height(perSampleTable), 1);
okM = isSuccess & okY & isfinite(perSampleTable.F_stop);
margin(okM) = (perSampleTable.yTrue(okM) - perSampleTable.F_stop(okM)) ./ yAbs(okM);
ratio(okM) = perSampleTable.F_stop(okM) ./ yAbs(okM);
perSampleTable.stoppingMargin = margin;
perSampleTable.stopForceRatio = ratio;

if nargin < 2 || isempty(summaryTable)
    summaryTable = table();
    return;
end

nSum = height(summaryTable);
utilMean = nan(nSum, 1);
utilSem = nan(nSum, 1);
marginMean = nan(nSum, 1);
marginSem = nan(nSum, 1);
ratioMean = nan(nSum, 1);
ratioSem = nan(nSum, 1);
failureRate = nan(nSum, 1);

for i = 1:nSum
    mask = string(perSampleTable.krMethodKey) == string(summaryTable.krMethodKey(i)) ...
        & abs(perSampleTable.alpha - summaryTable.alpha(i)) < 1e-9;

    valsU = perSampleTable.utilization(mask & isfinite(perSampleTable.utilization));
    if ~isempty(valsU)
        st = summarizeDeployMetricStats([], valsU);
        utilMean(i) = st.mean;
        utilSem(i) = st.sem;
    end

    valsM = perSampleTable.stoppingMargin(mask & isfinite(perSampleTable.stoppingMargin));
    if ~isempty(valsM)
        st = summarizeDeployMetricStats([], valsM);
        marginMean(i) = st.mean;
        marginSem(i) = st.sem;
    end

    valsR = perSampleTable.stopForceRatio(mask & isfinite(perSampleTable.stopForceRatio));
    if ~isempty(valsR)
        st = summarizeDeployMetricStats([], valsR);
        ratioMean(i) = st.mean;
        ratioSem(i) = st.sem;
    end

    if ismember("safeStopRate", summaryTable.Properties.VariableNames) ...
            && isfinite(summaryTable.safeStopRate(i))
        failureRate(i) = 1 - summaryTable.safeStopRate(i);
    elseif ismember("nSafeStopFail", summaryTable.Properties.VariableNames) ...
            && ismember("nCohort", summaryTable.Properties.VariableNames) ...
            && isfinite(summaryTable.nCohort(i)) && summaryTable.nCohort(i) > 0
        failureRate(i) = summaryTable.nSafeStopFail(i) / summaryTable.nCohort(i);
    end
end

summaryTable.utilization_success_mean = utilMean;
summaryTable.utilization_success_sem = utilSem;
summaryTable.stoppingMargin_success_mean = marginMean;
summaryTable.stoppingMargin_success_sem = marginSem;
summaryTable.stopForceRatio_success_mean = ratioMean;
summaryTable.stopForceRatio_success_sem = ratioSem;
summaryTable.failureRate = failureRate;
end
