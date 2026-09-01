function perSample = buildOfflineLoocvPerSampleTable(benchmark, methodKey, krVariant)
%buildOfflineLoocvPerSampleTable LOOCV 試料別絶対誤差表（id 付き）
%
% runKrMethodBenchmarkMethod と同じ valid マスクで cohort.ids を揃える。

perSample = table();
if isempty(benchmark) || ~isstruct(benchmark)
    return;
end
methodKey = string(methodKey);
if nargin < 3 || isempty(krVariant)
    krVariant = "chord";
end
krVariant = string(krVariant);

if ~isfield(benchmark, "methodKeys") || ~isfield(benchmark, "cvResults") ...
        || ~isfield(benchmark, "cohort")
    return;
end
mi = find(string(benchmark.methodKeys) == methodKey, 1);
if isempty(mi)
    return;
end

variants = string(benchmark.q1Variants);
if isempty(variants)
    variants = krVariant;
end
vi = find(variants == krVariant, 1);
if isempty(vi)
    vi = 1;
end

cvRes = benchmark.cvResults{mi, vi};
if isempty(cvRes) || ~isfield(cvRes, "yTrue") || ~isfield(cvRes, "yPred")
    return;
end

cohort = benchmark.cohort;
tbl = cohort.predictorTable;
krCol = resolveDeployKrColumn(tbl, methodKey, krVariant);
if ~ismember(krCol, tbl.Properties.VariableNames)
    return;
end

kr = tbl.(krCol)(:);
y = cohort.y(:);
ids = cohort.ids(:);
valid = isfinite(kr) & isfinite(y);
ids = ids(valid);
yTrue = cvRes.yTrue(:);
yPred = cvRes.yPred(:);
if numel(yTrue) ~= numel(ids)
    warning("buildOfflineLoocvPerSampleTable:SizeMismatch", ...
        "%s: cvResults と cohort valid 数が一致しません。", methodKey);
    return;
end

absErr = abs(yPred - yTrue);
perSample = table(ids, yTrue, yPred, absErr, ...
    'VariableNames', {'id', 'yTrue', 'y_hat_loocv', 'absErr_offline'});

end
