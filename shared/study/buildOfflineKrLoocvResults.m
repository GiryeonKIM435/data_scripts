function out = buildOfflineKrLoocvResults(cohort, cfg, opts)
%buildOfflineKrLoocvResults offline kr + LOOCV 校正結果

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "methodKey")
    opts.methodKey = cfg.paper.offlineKrMethodKey;
end
if ~isfield(opts, "krVariant")
    opts.krVariant = cfg.paper.offlineKrVariant;
end

tbl = cohort.predictorTable;
y = cohort.y(:);
n = cohort.n;
krCol = resolveDeployKrColumn(tbl, opts.methodKey, opts.krVariant);
krBatch = computePaperOfflineKrBatch(cohort, cfg, opts.methodKey, opts.krVariant);

methods = KrMethodRegistry();
mdef = lookupKrMethodRegistry(opts.methodKey, methods);

calib = fitDeployCalibLoocv(krBatch, y);
fitFn = @(Xtr, ytr, Xte) fitLinearPredict(Xtr, ytr, Xte);
validKr = isfinite(krBatch) & isfinite(y);
cvRes = runPairedLoocv(krBatch(validKr), y(validKr), fitFn);
maePct = calcMeanRelativeError(cvRes.yTrue, cvRes.yPred) * 100;
maeSem = absoluteErrorSem(cvRes.yTrue, cvRes.yPred);

out = struct();
out.methodKey = char(opts.methodKey);
out.krVariant = char(opts.krVariant);
out.krCol = char(krCol);
out.methodLabel = char(mdef.label);
out.krBatch = krBatch;
out.y = y;
out.calib = calib;
out.cvResults = cvRes;
out.meanKr = mean(krBatch(validKr));
validCalib = validKr & isfinite(calib.a) & isfinite(calib.b);
out.meanCalibA = mean(calib.a(validCalib));
out.meanCalibB = mean(calib.b(validCalib));
out.maePct = maePct;
out.maeSem = maeSem;
out.n = cvRes.n;
out.nCohort = n;

end
