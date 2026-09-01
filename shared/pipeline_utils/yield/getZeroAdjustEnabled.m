function enabled = getZeroAdjustEnabled(cfg)
%GETZEROADJUSTENABLED cfg から零点調整 ON/OFF を取得

enabled = true;
if nargin < 1 || isempty(cfg)
    return;
end
if isfield(cfg, "detectYield") && isfield(cfg.detectYield, "zeroAdjustFirstPoint")
    enabled = cfg.detectYield.zeroAdjustFirstPoint;
end

end
