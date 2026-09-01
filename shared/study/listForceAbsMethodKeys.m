function keys = listForceAbsMethodKeys(cfg)
%listForceAbsMethodKeys 初期荷重域（force_abs）30 条件の key 一覧
%
% ξ∈{0,5,10,20,30}, W∈{1,3,5,10,20,30} の force_sξ_wW。
% cfg.krMethodKeys があればその交差を優先し、無ければレジストリから列挙。

methods = KrMethodRegistry();
if nargin >= 1 && ~isempty(cfg) && isfield(cfg, "krMethodKeys") ...
        && ~isempty(cfg.krMethodKeys)
    cand = string(cfg.krMethodKeys(:));
else
    cand = string({methods.key})';
end

keys = strings(0, 1);
for i = 1:numel(cand)
    m = lookupKrMethodRegistry(cand(i), methods);
    if string(m.type) == "force_abs" && logical(m.gridValid)
        keys(end + 1, 1) = string(m.key); %#ok<AGROW>
    end
end
keys = unique(keys, "stable");
end
