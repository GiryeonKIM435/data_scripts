function summaryTable = augmentStreamingDeploySummaryWithBootstrap(summaryTable, perSampleTable, nBootstrap, seed)
%augmentStreamingDeploySummaryWithBootstrap Q3 summary に bootstrap列を追加

if nargin < 3 || isempty(nBootstrap)
    nBootstrap = 5000;
end
if nargin < 4 || isempty(seed)
    seed = 260417;
end
if isempty(summaryTable) || isempty(perSampleTable)
    return;
end

tag = "_b" + string(nBootstrap);
meanColMae = "finalUpdateMae_bootMean" + tag;
loColMae = "finalUpdateMae_ci_lo" + tag;
hiColMae = "finalUpdateMae_ci_hi" + tag;
hwColMae = "finalUpdateMae_ci_halfwidth" + tag;

meanColRel = "relativeFinalUpdateError_bootMean" + tag;
loColRel = "relativeFinalUpdateError_ci_lo" + tag;
hiColRel = "relativeFinalUpdateError_ci_hi" + tag;
hwColRel = "relativeFinalUpdateError_ci_halfwidth" + tag;

meanColSafe = "safeStopRate_bootMean" + tag;
loColSafe = "safeStopRate_ci_lo" + tag;
hiColSafe = "safeStopRate_ci_hi" + tag;
hwColSafe = "safeStopRate_ci_halfwidth" + tag;

cols = [meanColMae, loColMae, hiColMae, hwColMae, ...
    meanColRel, loColRel, hiColRel, hwColRel, ...
    meanColSafe, loColSafe, hiColSafe, hwColSafe];
for c = cols
    if ~ismember(c, summaryTable.Properties.VariableNames)
        summaryTable.(c) = nan(height(summaryTable), 1);
    end
end

for i = 1:height(summaryTable)
    key = string(summaryTable.krMethodKey(i));
    alpha = summaryTable.alpha(i);
    sub = perSampleTable(string(perSampleTable.krMethodKey) == key ...
        & abs(perSampleTable.alpha - alpha) < 1e-9, :);
    if isempty(sub)
        continue;
    end

    safeMask = string(sub.outcome) == "success";
    safeBoot = bootstrapDeployMetricStats(safeMask, [], struct( ...
        "nBootstrap", nBootstrap, ...
        "seed", seed + i));
    summaryTable.(meanColSafe)(i) = safeBoot.bootstrapMean;
    summaryTable.(loColSafe)(i) = safeBoot.ci_lo;
    summaryTable.(hiColSafe)(i) = safeBoot.ci_hi;
    summaryTable.(hwColSafe)(i) = 0.5 * (safeBoot.ci_hi - safeBoot.ci_lo);

    evalMask = isfinite(sub.finalUpdateErrorN);
    errs = sub.finalUpdateErrorN(evalMask);
    maeBoot = bootstrapDeployMetricStats([], errs, struct( ...
        "nBootstrap", nBootstrap, ...
        "seed", seed + 100000 + i));
    summaryTable.(meanColMae)(i) = maeBoot.bootstrapMean;
    summaryTable.(loColMae)(i) = maeBoot.ci_lo;
    summaryTable.(hiColMae)(i) = maeBoot.ci_hi;
    summaryTable.(hwColMae)(i) = 0.5 * (maeBoot.ci_hi - maeBoot.ci_lo);

    relErr = sub.relativeFinalUpdateError(evalMask);
    relBoot = bootstrapDeployMetricStats([], relErr, struct( ...
        "nBootstrap", nBootstrap, ...
        "seed", seed + 200000 + i));
    summaryTable.(meanColRel)(i) = relBoot.bootstrapMean;
    summaryTable.(loColRel)(i) = relBoot.ci_lo;
    summaryTable.(hiColRel)(i) = relBoot.ci_hi;
    summaryTable.(hwColRel)(i) = 0.5 * (relBoot.ci_hi - relBoot.ci_lo);
end

end
