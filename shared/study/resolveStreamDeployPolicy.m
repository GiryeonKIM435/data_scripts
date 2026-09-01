function policy = resolveStreamDeployPolicy(sampleOpts, cfg)
%resolveStreamDeployPolicy ストリーミング deploy の kr 更新ポリシーを解決

if nargin < 1 || isempty(sampleOpts)
    sampleOpts = struct();
end

policy = struct();
policy.minBandPointsForKr = 5;
policy.percentYieldBandGatePoints = 3;

if isfield(sampleOpts, "minBandPointsForKr") && isfinite(sampleOpts.minBandPointsForKr)
    policy.minBandPointsForKr = max(1, round(double(sampleOpts.minBandPointsForKr)));
elseif nargin >= 2 && ~isempty(cfg) && isfield(cfg, "deploy") ...
        && isfield(cfg.deploy, "minBandPointsForKr") && isfinite(cfg.deploy.minBandPointsForKr)
    policy.minBandPointsForKr = max(1, round(double(cfg.deploy.minBandPointsForKr)));
end

if isfield(sampleOpts, "percentYieldBandGatePoints") && isfinite(sampleOpts.percentYieldBandGatePoints)
    policy.percentYieldBandGatePoints = max(0, round(double(sampleOpts.percentYieldBandGatePoints)));
elseif nargin >= 2 && ~isempty(cfg) && isfield(cfg, "deploy") ...
        && isfield(cfg.deploy, "percentYieldBandGatePoints") ...
        && isfinite(cfg.deploy.percentYieldBandGatePoints)
    policy.percentYieldBandGatePoints = max(0, round(double(cfg.deploy.percentYieldBandGatePoints)));
end

end
