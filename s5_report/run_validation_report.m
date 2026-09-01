function results = run_validation_report(cfg, opts)
%RUN_VALIDATION_REPORT 後方互換ラッパ（論文用 Q0 へ委譲）

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end

results = run_paper_report(cfg, opts);

end
