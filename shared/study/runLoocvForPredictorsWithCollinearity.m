function result = runLoocvForPredictorsWithCollinearity(tbl, y, predictors, cvCfg, opts)
%runLoocvForPredictorsWithCollinearity fold 内共線性除去付き LOOCV

predictors = string(predictors(:));
y = double(y(:));
n = numel(y);

if nargin < 5 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "collinearityMode")
    opts.collinearityMode = "none";
end
if ~isfield(opts, "protectedPredictors")
    opts.protectedPredictors = string.empty(0, 1);
end

collinearityMode = string(opts.collinearityMode);
protectedPredictors = string(opts.protectedPredictors(:));

% Drop incomplete rows for the candidate predictors (needed when force-kept
% samples introduce NaN in weight/d_eq/kr, etc.).
ok = isfinite(y);
for pi = 1:numel(predictors)
    col = predictors(pi);
    if ismember(col, string(tbl.Properties.VariableNames))
        ok = ok & isfinite(double(tbl{:, char(col)}));
    else
        error("runLoocvForPredictorsWithCollinearity:MissingCol", ...
            "predictor column missing: %s", col);
    end
end
if ~all(ok)
    fprintf("LOOCV collinearity: drop %d/%d rows with nonfinite predictors\n", ...
        nnz(~ok), numel(ok));
    tbl = tbl(ok, :);
    y = y(ok);
    n = numel(y);
end
if n < 3
    error("runLoocvForPredictorsWithCollinearity:TooFewRows", ...
        "Too few complete rows for LOOCV (n=%d).", n);
end

if collinearityMode ~= "fold_inner"
    result = runLoocvForPredictors(tbl, y, predictors);
    result.foldSelected = repmat({predictors}, n, 1);
    result.foldRemovedLog = repmat({struct("removedVariable", {}, "reason", {}, "metric", {}, "value", {})}, n, 1);
    return;
end

yPred = nan(n, 1);
foldSelected = cell(n, 1);
foldRemovedLog = cell(n, 1);

for i = 1:n
    trMask = true(n, 1);
    trMask(i) = false;
    tblTr = tbl(trMask, :);
    yTr = y(trMask);

    [selected, removedLog] = selectIndependentPredictorsProtected( ...
        tblTr, predictors, cvCfg, protectedPredictors);
    foldSelected{i} = selected;
    foldRemovedLog{i} = removedLog;

    if isempty(selected)
        continue;
    end

    Xtr = tblTr{:, cellstr(selected)};
    Xte = tbl{i, cellstr(selected)};
    if numel(selected) == 1
        yPred(i) = predictStandardizedOlsFold(Xtr, yTr, Xte);
    else
        yPred(i) = predictStandardizedOlsFold(Xtr, yTr, Xte);
    end
end

cvRes = struct();
cvRes.scheme = "LOOCV";
cvRes.n = n;
cvRes.yTrue = y;
cvRes.yPred = yPred;
cvRes.metrics = calcMetrics(y, yPred);
cvRes.residuals = y - yPred;

result = struct();
result.predictors = predictors;
result.cv = cvRes;
result.metrics = cvRes.metrics;
result.foldSelected = foldSelected;
result.foldRemovedLog = foldRemovedLog;
end
