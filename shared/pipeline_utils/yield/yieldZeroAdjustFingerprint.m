function fp = yieldZeroAdjustFingerprint(cfg)
%YIELDZEROADJUSTFINGERPRINT 零点調整設定の指紋

if nargin < 1 || isempty(cfg)
    cfg = PipelineConfig();
end

enabled = true;
if isfield(cfg, "detectYield") && isfield(cfg.detectYield, "zeroAdjustFirstPoint")
    enabled = cfg.detectYield.zeroAdjustFirstPoint;
end

if enabled
    fp = "first_valid_point";
else
    fp = "none";
end

end
