function methodKeys = resolveQ7MethodKeys(cfg)
%resolveQ7MethodKeys force_abs / force_trailing のみ（pct 除外）

methods = KrMethodRegistry();
allowed = string(cfg.q7.methodTypes(:));
keys = string(cfg.krMethodKeys(:));
keep = false(numel(keys), 1);
for i = 1:numel(keys)
    mdef = lookupKrMethodRegistry(keys(i), methods);
    keep(i) = any(string(mdef.type) == allowed);
end
methodKeys = keys(keep);
if isempty(methodKeys)
    error("resolveQ7MethodKeys:Empty", ...
        "Q7 対象方式が空です (methodTypes=%s)。", strjoin(allowed, ","));
end
methodKeys = orderForceAbsFirst(methodKeys, methods);
end

function order = orderForceAbsFirst(methodKeys, methods)
priority = struct("force_abs", 1, "force_trailing", 2);
scores = 99 * ones(numel(methodKeys), 1);
for i = 1:numel(methodKeys)
    mdef = lookupKrMethodRegistry(methodKeys(i), methods);
    t = char(string(mdef.type));
    if isfield(priority, t)
        scores(i) = priority.(t);
    end
end
[~, ord] = sort(scores);
order = methodKeys(ord);
end
