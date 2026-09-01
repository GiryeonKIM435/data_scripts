function [defAdj, forceAdj, meta] = zeroAdjustDefForceFirstPoint(def, force, enabled)
%ZEROADJUSTDEFFORCEFIRSTPOINT 先頭有効点を (0,0) に平行移動

if nargin < 3 || isempty(enabled)
    enabled = true;
end

def = def(:);
force = force(:);
valid = isfinite(def) & isfinite(force);
def = def(valid);
force = force(valid);

meta = struct( ...
    "defOffsetMm", 0, ...
    "forceOffsetN", 0, ...
    "nValid", numel(def), ...
    "applied", false);

if isempty(def)
    defAdj = def;
    forceAdj = force;
    return;
end

if ~enabled
    defAdj = def;
    forceAdj = force;
    return;
end

meta.defOffsetMm = def(1);
meta.forceOffsetN = force(1);
defAdj = def - meta.defOffsetMm;
forceAdj = force - meta.forceOffsetN;
meta.applied = true;

end
