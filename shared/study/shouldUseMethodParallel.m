function tf = shouldUseMethodParallel(cfg, nMethods, stage)
%shouldUseMethodParallel 方式単位の並列（parfeval）を使うか

if nargin < 3 || isempty(stage)
    stage = "deploy";
end

tf = false;
if ~(isfinite(nMethods) && nMethods >= 1)
    return;
end

useParfor = resolveStageUseParfor(cfg, stage);
poolInfo = ensurePaperStudyParallelPool(cfg);
threshold = 8;
if isfield(cfg, "parallel") && isfield(cfg.parallel, "methodParallelThreshold") ...
        && isfinite(cfg.parallel.methodParallelThreshold)
    threshold = cfg.parallel.methodParallelThreshold;
end

tf = useParfor && poolInfo.active && nMethods >= threshold;

end

function useParfor = resolveStageUseParfor(cfg, stage)
useParfor = false;
if isfield(cfg, "parallel") && isfield(cfg.parallel, "enabled")
    useParfor = logical(cfg.parallel.enabled);
end
stage = lower(string(stage));
if stage == "q1" && isfield(cfg, "q1") && isfield(cfg.q1, "useParfor")
    useParfor = logical(cfg.q1.useParfor);
elseif stage == "deploy" && isfield(cfg, "deploy") && isfield(cfg.deploy, "useParfor")
    useParfor = logical(cfg.deploy.useParfor);
elseif stage == "q4" && isfield(cfg, "q4") && isfield(cfg.q4, "useParfor")
    useParfor = logical(cfg.q4.useParfor);
end
end
