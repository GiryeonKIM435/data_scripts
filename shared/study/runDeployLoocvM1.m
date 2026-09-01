function res = runDeployLoocvM1(krBatch, y, ids, methodDef, artifacts)
%runDeployLoocvM1 LOO: train=オフライン kr, test=リアルタイム kr

y = double(y(:));
ids = double(ids(:));
krBatch = double(krBatch(:));
n = numel(y);
if numel(krBatch) ~= n || numel(ids) ~= n
    error("runDeployLoocvM1:SizeMismatch", "入力サイズが一致しません。");
end

yPred = nan(n, 1);
krRt = nan(n, 1);
krSuccess = false(n, 1);
nBand = nan(n, 1);
fitR2 = nan(n, 1);
bandEndOverYield = nan(n, 1);
marginN = nan(n, 1);

fitFn = @(Xtr, ytr, Xte) fitLinearPredict(Xtr, ytr, Xte);

for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    krTr = krBatch(tr);
    yTr = y(tr);
    validTr = isfinite(krTr) & isfinite(yTr);
    if nnz(validTr) < 2
        continue;
    end

    branch = getDeployBranchCache(artifacts, ids(i));
    est = estimateKrFromRawSample(branch, methodDef, artifacts.fitCfg);
    if ~est.success || ~isfinite(est.krLs)
        continue;
    end

    krRt(i) = est.krLs;
    krSuccess(i) = true;
    nBand(i) = est.nBand;
    fitR2(i) = est.r2;
    bandEndOverYield(i) = est.bandEndOverYield;
    yPred(i) = fitFn(krTr(validTr), yTr(validTr), krRt(i));
    marginN(i) = y(i) - yPred(i);
end

valid = isfinite(yPred) & isfinite(y);
if nnz(valid) >= 2
    metrics = calcMetrics(y(valid), yPred(valid));
else
    metrics = struct("mae", nan, "rmse", nan, "r2", nan);
end
safety = summarizeDeploySafetyMetrics(y, yPred);

res = struct();
res.scheme = "deploy_LOOCV_M1";
res.n = n;
res.nUsed = nnz(valid);
res.krSuccessRate = mean(krSuccess);
res.yTrue = y;
res.yPred = yPred;
res.krRt = krRt;
res.krSuccess = krSuccess;
res.nBand = nBand;
res.fitR2 = fitR2;
res.bandEndOverYield = bandEndOverYield;
res.marginN = marginN;
res.metrics = metrics;
res.safety = safety;
res.ids = ids;
end
