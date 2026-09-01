function summaryRow = summarizeStreamingDeployOutcomes(outcomes, meta)
%summarizeStreamingDeployOutcomes 方式×alpha の fold 結果を集計

if isempty(outcomes)
    summaryRow = emptyStreamingSummaryRow(meta);
    return;
end

outcomeStr = string({outcomes.outcome});
n = numel(outcomes);

summaryRow = meta;
summaryRow.nCohort = n;
summaryRow.nUsed = n;

safeMask = outcomeStr == "success";

safeStats = summarizeDeployMetricStats(safeMask);
summaryRow.safeSuccessRate = safeStats.mean;
summaryRow.safeStopRate = safeStats.mean;
summaryRow.safeStopRate_sem = safeStats.sem;
summaryRow.nSafeStopFail = sum(~safeMask);

summaryRow.fail_cross_warmup = mean(outcomeStr == "fail_cross_warmup");
summaryRow.fail_cross_after_pred = mean(outcomeStr == "fail_cross_after_pred");
summaryRow.fail_never_stopped = mean(outcomeStr == "fail_never_stopped");
summaryRow.fail_no_kr = mean(outcomeStr == "fail_no_kr");

evalMask = arrayfun(@(o) isfinite(o.finalUpdateErrorN), outcomes);
summaryRow.nEvaluated = sum(evalMask);
summaryRow.nNoPrediction = n - summaryRow.nEvaluated;

if any(evalMask)
    finalErrs = [outcomes(evalMask).finalUpdateErrorN];
    relFinalErrs = [outcomes(evalMask).relativeFinalUpdateError];
    yTrue = [outcomes(evalMask).yTrue];
    yPred = [outcomes(evalMask).y_hat_finalUpdate];
    maeStats = summarizeDeployMetricStats([], finalErrs);
    relStats = summarizeDeployMetricStats([], relFinalErrs);
    r2Metrics = calcMetrics(yTrue(:), yPred(:));
    summaryRow.finalUpdateMae = maeStats.mean;
    summaryRow.finalUpdateMae_sem = maeStats.sem;
    summaryRow.finalUpdateR2 = r2Metrics.r2;
    summaryRow.relativeFinalUpdateError_mean = relStats.mean;
    summaryRow.relativeFinalUpdateError_sem = relStats.sem;
else
    summaryRow.finalUpdateMae = nan;
    summaryRow.finalUpdateMae_sem = nan;
    summaryRow.finalUpdateR2 = nan;
    summaryRow.relativeFinalUpdateError_mean = nan;
    summaryRow.relativeFinalUpdateError_sem = nan;
end

% 後方互換: 成功停止例のみの stop MAE（参照用）
if any(safeMask)
    errs = [outcomes(safeMask).stopErrorN];
    relErrs = [outcomes(safeMask).relativeStopError];
    yTrue = [outcomes(safeMask).yTrue];
    yPred = [outcomes(safeMask).y_hat_at_stop];
    maeStats = summarizeDeployMetricStats([], errs);
    relStats = summarizeDeployMetricStats([], relErrs);
    r2Metrics = calcMetrics(yTrue(:), yPred(:));
    summaryRow.stopMae_success = maeStats.mean;
    summaryRow.stopMae_success_sem = maeStats.sem;
    summaryRow.stopR2_success = r2Metrics.r2;
    summaryRow.relativeStopError_success_mean = relStats.mean;
    summaryRow.relativeStopError_success_sem = relStats.sem;
else
    summaryRow.stopMae_success = nan;
    summaryRow.stopMae_success_sem = nan;
    summaryRow.stopR2_success = nan;
    summaryRow.relativeStopError_success_mean = nan;
    summaryRow.relativeStopError_success_sem = nan;
end

warmupSteps = [outcomes.nStepsToFirstKr];
warmupSteps = warmupSteps(isfinite(warmupSteps));
if ~isempty(warmupSteps)
    warmupStats = summarizeDeployMetricStats([], warmupSteps);
    summaryRow.warmupStepsMean = warmupStats.mean;
    summaryRow.warmupSteps_sem = warmupStats.sem;
else
    summaryRow.warmupStepsMean = nan;
    summaryRow.warmupSteps_sem = nan;
end

end

function row = emptyStreamingSummaryRow(meta)
row = meta;
row.nCohort = 0;
row.nUsed = 0;
row.safeSuccessRate = nan;
row.safeStopRate = nan;
row.safeStopRate_sem = nan;
row.nSafeStopFail = 0;
row.fail_cross_warmup = nan;
row.fail_cross_after_pred = nan;
row.fail_never_stopped = nan;
row.fail_no_kr = nan;
row.nEvaluated = 0;
row.nNoPrediction = 0;
row.finalUpdateMae = nan;
row.finalUpdateMae_sem = nan;
row.finalUpdateR2 = nan;
row.relativeFinalUpdateError_mean = nan;
row.relativeFinalUpdateError_sem = nan;
row.stopMae_success = nan;
row.stopMae_success_sem = nan;
row.stopR2_success = nan;
row.relativeStopError_success_mean = nan;
row.relativeStopError_success_sem = nan;
row.warmupStepsMean = nan;
row.warmupSteps_sem = nan;
end
