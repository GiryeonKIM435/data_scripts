function results = runCvEvaluation(X, y, fitFn, cvCfg)
%runCvEvaluation full / LOOCV / K-fold CV 評価の共通エンジン
%
% fitFn: @(Xtr, ytr, Xte) -> yPredTe

if nargin < 4 || isempty(cvCfg)
    cvCfg = CvConfig();
end

y = double(y(:));
n = numel(y);
if size(X, 1) ~= n
    error("runCvEvaluation:SizeMismatch", "X と y の行数が一致しません。");
end

results = struct();
results.n = n;

% --- full fit ---
yPredFull = fitFn(X, y, X);
results.full = packScheme(calcMetrics(y, yPredFull), yPredFull, "full");

% --- LOOCV ---
yPredLoo = nan(n, 1);
for i = 1:n
    tr = true(n, 1); tr(i) = false;
    yPredLoo(i) = fitFn(X(tr, :), y(tr), X(i, :));
end
results.loocv = packScheme(calcMetrics(y, yPredLoo), yPredLoo, "LOOCV");

% --- K-fold ---
nFolds = cvCfg.cvFolds;
if n < nFolds + 2
    results.kfold = struct("scheme", sprintf("%d-fold", nFolds), "skipped", true, ...
        "reason", sprintf("n=%d < folds+2", n));
else
    rng(cvCfg.cvSeed, "twister");
    cvp = cvpartition(n, "KFold", nFolds);
    yPredK = nan(n, 1);
    for f = 1:nFolds
        tr = training(cvp, f);
        te = test(cvp, f);
        yPredK(te) = fitFn(X(tr, :), y(tr), X(te, :));
    end
    results.kfold = packScheme(calcMetrics(y, yPredK), yPredK, sprintf("%d-fold", nFolds));
    results.kfold.cvSeed = cvCfg.cvSeed;
    results.kfold.skipped = false;
end

end

function s = packScheme(metrics, yPred, schemeName)
s = metrics;
s.scheme = schemeName;
s.yPred = yPred;
end
