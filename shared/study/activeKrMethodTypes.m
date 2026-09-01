function types = activeKrMethodTypes(cfg)
%activeKrMethodTypes paper study / Q3 で評価する kr 方式 type 一覧

allTypes = ["percent_yield", "force_abs", "force_trailing"];

if nargin < 1 || isempty(cfg) || ~isfield(cfg, "krMethodKeys") || isempty(cfg.krMethodKeys)
    types = allTypes;
    return;
end

methods = KrMethodRegistry();
present = strings(0, 1);
for key = string(cfg.krMethodKeys(:))'
    mdef = lookupKrMethodRegistry(key, methods);
    present(end + 1, 1) = string(mdef.type); %#ok<AGROW>
end
present = unique(present, "stable");
types = allTypes(ismember(allTypes, present));

if isempty(types)
    types = allTypes;
end

end
