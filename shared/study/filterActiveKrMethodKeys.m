function keys = filterActiveKrMethodKeys(methodKeys, methods, excludeTypes)
%filterActiveKrMethodKeys time_abs / time_trailing および任意 type を除外

if nargin < 2 || isempty(methods)
    methods = KrMethodRegistry();
end
if nargin < 3
    excludeTypes = string.empty(0, 1);
end

methodKeys = string(methodKeys(:));
excludeTypes = string(excludeTypes(:));
inactive = unique([string("time_abs"), string("time_trailing"), excludeTypes(:)']);

keep = true(size(methodKeys));
for i = 1:numel(methodKeys)
    mdef = lookupKrMethod(methodKeys(i), methods);
    if ismember(string(mdef.type), inactive)
        keep(i) = false;
    end
end
keys = methodKeys(keep);

end

function m = lookupKrMethod(key, methods)
m = methods(1);
for i = 1:numel(methods)
    if string(methods(i).key) == string(key)
        m = methods(i);
        return;
    end
end
end
