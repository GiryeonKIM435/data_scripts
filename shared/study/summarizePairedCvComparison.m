function summary = summarizePairedCvComparison(cvA, cvB, cfg, opts)
%summarizePairedCvComparison ペア LOOCV 比較の統計量サマリ
%
% cvA, cvB: LOOCV 結果（delta = metric(A) - metric(B)）

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 4 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "modelA")
    opts.modelA = "A";
end
if ~isfield(opts, "modelB")
    opts.modelB = "B";
end

stats = pairedResidualTest(cvA, cvB, cfg);
y = cvA.yTrue(:);
predA = cvA.yPred(:);
predB = cvB.yPred(:);
absA = abs(y - predA);
absB = abs(y - predB);
pairDiff = absB - absA;

summary = struct();
summary.modelA = string(opts.modelA);
summary.modelB = string(opts.modelB);
summary.deltaMae = stats.deltaMae;
summary.deltaRmse = stats.deltaRmse;
summary.deltaR2 = stats.deltaR2;
summary.ciDeltaMae = stats.ciDeltaMae;
summary.ciDeltaR2 = stats.ciDeltaR2;
summary.pWilcoxonMae = stats.pWilcoxonMae;
summary.pBootstrapMae = stats.pBootstrapMae;
summary.winRateA = mean(absA < absB, "omitnan");
summary.n = numel(y);
summary.nWinA = nnz(absA < absB);
summary.cohenDz = cohenDz(pairDiff);
summary.pWilcoxonOneSidedImproveA = oneSidedWilcoxon(absA, absB);
summary.perSampleAbsErrorDiff = pairDiff;
summary.yTrue = y;
summary.absErrorA = absA;
summary.absErrorB = absB;
end

function dz = cohenDz(diffVals)
diffVals = diffVals(isfinite(diffVals));
if numel(diffVals) < 2
    dz = nan;
    return;
end
sdDiff = std(diffVals, 0);
if sdDiff == 0
    dz = nan;
else
    dz = mean(diffVals) / sdDiff;
end
end

function pOne = oneSidedWilcoxon(absA, absB)
% H1: median(|e_A|) < median(|e_B|) i.e. A has smaller absolute errors
try
    pOne = signrank(absA, absB, "Tail", "left");
catch
    pOne = nan;
end
end
