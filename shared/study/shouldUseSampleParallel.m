function tf = shouldUseSampleParallel(cfg, nMethods, stage)
%shouldUseSampleParallel 試料単位の並列を使うか（方式並列と排他）

if nargin < 3 || isempty(stage)
    stage = "deploy";
end

tf = false;
if shouldUseMethodParallel(cfg, nMethods, stage)
    return;
end

useParfor = resolveStageUseParfor(cfg, stage);
poolInfo = ensurePaperStudyParallelPool(cfg);
if ~(useParfor && poolInfo.active)
    return;
end

if stage == "deploy"
    if isfield(cfg, "deploy") && isfield(cfg.deploy, "parallelSamples")
        tf = logical(cfg.deploy.parallelSamples);
    else
        tf = true;
    end
    return;
end

tf = true;

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
