function results = run_jeffreys_fit_audit(cfg, opts)
%RUN_JEFFREYS_FIT_AUDIT Methods audit for Jeffreys creep identification

if nargin < 1
    cfg = [];
end
if nargin < 2
    opts = struct();
end
results = run_burgers_fit_audit(cfg, opts);
end
