function out = bootstrapPairedDeltaTest(refAbsErr, cmpAbsErr, opts)
%bootstrapPairedDeltaTest ペア絶対誤差差(候補-基準)の bootstrap CI/p

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

out = struct("nPaired", 0, "deltaMean", nan, "ci_lo", nan, "ci_hi", nan, ...
    "pTwoSided", nan, "nBootstrap", opts.nBootstrap);

refAbsErr = double(refAbsErr(:));
cmpAbsErr = double(cmpAbsErr(:));
if numel(refAbsErr) ~= numel(cmpAbsErr)
    return;
end

mask = isfinite(refAbsErr) & isfinite(cmpAbsErr);
delta = cmpAbsErr(mask) - refAbsErr(mask);
n = numel(delta);
out.nPaired = n;
if n < 3
    return;
end

out.deltaMean = mean(delta);
B = max(1, round(double(opts.nBootstrap)));
stream = RandStream("twister", "Seed", double(opts.seed));
bootDelta = nan(B, 1);
for b = 1:B
    idx = randi(stream, n, n, 1);
    bootDelta(b) = mean(delta(idx));
end

out.nBootstrap = B;
out.pTwoSided = computeBootstrapTwoSidedP(bootDelta);
qLo = 100 * (opts.alpha / 2);
qHi = 100 * (1 - opts.alpha / 2);
qs = prctile(bootDelta, [qLo, qHi]);
out.ci_lo = qs(1);
out.ci_hi = qs(2);

end
