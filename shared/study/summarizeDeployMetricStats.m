function stats = summarizeDeployMetricStats(binaryFlags, continuousVals)
%summarizeDeployMetricStats 率・連続量の算術平均と SEM

stats = struct();
stats.n = 0;
stats.mean = nan;
stats.sem = nan;

if nargin < 1 || isempty(binaryFlags)
    binaryFlags = false(0, 1);
else
    binaryFlags = logical(binaryFlags(:));
end

nBin = numel(binaryFlags);
if nBin > 0
    p = mean(binaryFlags);
    stats.n = nBin;
    stats.mean = p;
    stats.sem = binomialSem(p, nBin);
end

if nargin >= 2 && ~isempty(continuousVals)
    x = continuousVals(:);
    x = x(isfinite(x));
    if ~isempty(x)
        stats.n = numel(x);
        stats.mean = mean(x);
        stats.sem = continuousSem(x);
    end
end

end

function sem = binomialSem(p, n)
if n <= 0 || ~isfinite(p)
    sem = nan;
    return;
end
p = min(max(p, 0), 1);
sem = sqrt(p * (1 - p) / n);
end

function sem = continuousSem(x)
n = numel(x);
if n <= 1
    sem = nan;
    return;
end
sem = std(x, 0) / sqrt(n);
end
