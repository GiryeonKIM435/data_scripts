function calib = fitDeployCalibLoocv(krBatch, y)
%fitDeployCalibLoocv Phase A: オフライン kr から LOO (a,b) を推定

y = double(y(:));
krBatch = double(krBatch(:));
n = numel(y);
if numel(krBatch) ~= n
    error("fitDeployCalibLoocv:SizeMismatch", "入力サイズが一致しません。");
end

a = nan(n, 1);
b = nan(n, 1);
for i = 1:n
    tr = true(n, 1);
    tr(i) = false;
    krTr = krBatch(tr);
    yTr = y(tr);
    validTr = isfinite(krTr) & isfinite(yTr);
    if nnz(validTr) < 2
        continue;
    end
    X = [ones(nnz(validTr), 1), krTr(validTr)];
    beta = X \ yTr(validTr);
    b(i) = beta(1);
    a(i) = beta(2);
end

calib = struct();
calib.a = a;
calib.b = b;
calib.n = n;
calib.nValid = nnz(isfinite(a) & isfinite(b));

end
