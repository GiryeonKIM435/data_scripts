function results = run_prepare_burgers_bi_iqr15(cfg, opts)
%RUN_PREPARE_BURGERS_BI_IQR15 Compatibility wrapper -> run_prepare_jeffreys_bi_iqr15
if nargin < 1, cfg = []; end
if nargin < 2, opts = []; end
results = run_prepare_jeffreys_bi_iqr15(cfg, opts);
end
