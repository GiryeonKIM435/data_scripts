function pack = runKrMethodBenchmarkMethod(key, meta, krBatches, variants, y, cohortN, nSuccess, nComplete, cfg, commonCaseOnly, deployKrVariant)
%runKrMethodBenchmarkMethod Q1: 1 方式分の LOOCV 評価（parfeval 用）

variants = string(variants(:));
nVar = numel(variants);
y = y(:);
fitFn = @(Xtr, ytr, Xte) fitLinearPredict(Xtr, ytr, Xte);
deployKrVariant = string(deployKrVariant);

rows = cell(nVar, 19);
cvResults = cell(1, nVar);
deployCalib = [];

for vi = 1:nVar
    variant = variants(vi);
    kr = krBatches{vi}(:);
    if variant == deployKrVariant && ~commonCaseOnly
        deployCalib = fitDeployCalibLoocv(kr, y);
    end

    valid = isfinite(kr) & isfinite(y);
    if ~all(valid)
        badN = nnz(~valid);
        warning("runKrMethodBenchmarkMethod:SkipNaN", ...
            "%s(%s): %d 試料が非有限のため除外", key, variant, badN);
        kr = kr(valid);
        yUse = y(valid);
    else
        yUse = y;
    end

    if numel(yUse) < 3
        cvRes = struct();
        cvRes.metrics = struct("r2", nan, "mae", nan, "rmse", nan);
        cvRes.yTrue = yUse;
        cvRes.yPred = nan(size(yUse));
        relErr = nan;
        maeSem = nan;
        relSem = nan;
    else
        cvRes = runPairedLoocv(kr, yUse, fitFn);
        relErr = calcMeanRelativeError(cvRes.yTrue, cvRes.yPred);
        maeSem = absoluteErrorSem(cvRes.yTrue, cvRes.yPred);
        relSem = relativeErrorSem(cvRes.yTrue, cvRes.yPred);
    end

    rows(vi, :) = {char(key), char(variant), char(meta.methodType), meta.gridStart, meta.gridWidth, meta.gridValid, ...
        char(meta.label), char(meta.leakCategory), char(meta.leakNote), ...
        cohortN, numel(yUse), nSuccess, nComplete, ...
        cvRes.metrics.r2, cvRes.metrics.mae, maeSem, cvRes.metrics.rmse, relErr, relSem};
    cvResults{vi} = cvRes;
end

pack = struct();
pack.rows = rows;
pack.cvResults = cvResults;
pack.deployCalib = deployCalib;
pack.deployCalibChord = deployCalib;

end
