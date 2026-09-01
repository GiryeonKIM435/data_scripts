function coefTbl = fitM3CoefficientsExploratory(X, y, predNames)
%fitM3CoefficientsExploratory 全データ M3 OLS（探索的、非 CV）

predNames = string(predNames(:));
u = pipelineUtils();
[Z, ~, ~] = u.zscoreSafe(X);
[yZ, ~, ~] = u.zscoreSafe(y);
mdlFull = fitlm(Z, yZ);
ct = mdlFull.Coefficients(2:end, :);
deltaR2Drop = nan(numel(predNames), 1);
for i = 1:numel(predNames)
    keep = true(numel(predNames), 1);
    keep(i) = false;
    if ~any(keep)
        deltaR2Drop(i) = nan;
        continue;
    end
    mdlDrop = fitlm(Z(:, keep), yZ);
    deltaR2Drop(i) = mdlFull.Rsquared.Ordinary - mdlDrop.Rsquared.Ordinary;
end
coefTbl = table(predNames, ct.Estimate, ct.SE, ct.pValue, deltaR2Drop, ...
    'VariableNames', {'predictor', 'betaStd', 'seStd', 'pValue', 'deltaR2DropExploratory'});
coefTbl.analysisNote = repmat("exploratory_full_sample_not_cv", height(coefTbl), 1);
end
