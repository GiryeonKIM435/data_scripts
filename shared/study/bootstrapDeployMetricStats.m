function out = bootstrapDeployMetricStats(binaryFlags, continuousVals, opts)
%bootstrapDeployMetricStats 率・連続量の bootstrap 平均/CI

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "nBootstrap") || isempty(opts.nBootstrap)
    opts.nBootstrap = 5000;
end
if ~isfield(opts, "seed") || isempty(opts.seed)
    opts.seed = 260417;
end
if ~isfield(opts, "alpha") || isempty(opts.alpha)
    opts.alpha = 0.05;
end

out = struct("n", 0, "mean", nan, "ci_lo", nan, "ci_hi", nan, ...
    "bootstrapMean", nan, "nBootstrap", opts.nBootstrap);

if nargin < 1 || isempty(binaryFlags)
    binaryFlags = false(0, 1);
else
    binaryFlags = logical(binaryFlags(:));
end

useContinuous = nargin >= 2 && ~isempty(continuousVals);
if useContinuous
    x = double(continuousVals(:));
    x = x(isfinite(x));
else
    x = double(binaryFlags(:));
end

n = numel(x);
out.n = n;
if n == 0
    return;
end
out.mean = mean(x);

B = max(1, round(double(opts.nBootstrap)));
stream = RandStream("twister", "Seed", double(opts.seed));
bootVals = nan(B, 1);
for b = 1:B
    idx = randi(stream, n, n, 1);
    bootVals(b) = mean(x(idx));
end

out.bootstrapMean = mean(bootVals);
out.nBootstrap = B;
qLo = 100 * (opts.alpha / 2);
qHi = 100 * (1 - opts.alpha / 2);
qs = prctile(bootVals, [qLo, qHi]);
out.ci_lo = qs(1);
out.ci_hi = qs(2);

end
