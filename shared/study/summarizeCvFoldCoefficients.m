function summaryTbl = summarizeCvFoldCoefficients(foldTbl, predictors, cfg)
%summarizeCvFoldCoefficients fold 係数の要約 + bootstrap CI

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end

predictors = string(predictors(:));
B = cfg.cv.bootstrapSamples;
rng(cfg.cv.bootstrapSeed + 1, "twister");
nFold = height(foldTbl);

rows = cell(numel(predictors), 8);
for pi = 1:numel(predictors)
    p = predictors(pi);
    vals = foldTbl.(p);
    posRate = mean(vals > 0, "omitnan");
    bootMean = nan(B, 1);
    for b = 1:B
        idx = randi(nFold, nFold, 1);
        bootMean(b) = mean(vals(idx), "omitnan");
    end
    ci = quantile(bootMean, [0.025, 0.975]);
    rows(pi, :) = {char(p), mean(vals, "omitnan"), std(vals, 0, "omitnan"), ...
        posRate, ci(1), ci(2), nFold, "loocv_fold_standardized"};
end
summaryTbl = cell2table(rows, 'VariableNames', { ...
    'predictor', 'meanBetaStd', 'sdBetaStd', 'positiveSignRate', ...
    'ciMeanLo', 'ciMeanHi', 'nFolds', 'source'});
end
