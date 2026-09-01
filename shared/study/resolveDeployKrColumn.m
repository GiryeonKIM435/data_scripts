function krCol = resolveDeployKrColumn(tbl, methodKey, krVariant)
%resolveDeployKrColumn デプロイ用 offline kr 列名

methodKey = string(methodKey);
if nargin < 3 || isempty(krVariant)
    krVariant = "chord";
end

switch string(krVariant)
    case "chord"
        krCol = "krChord_" + methodKey;
    case "ls"
        krCol = "krLs_" + methodKey;
    otherwise
        error("resolveDeployKrColumn:BadVariant", "未知の krVariant: %s", krVariant);
end

if ~ismember(krCol, tbl.Properties.VariableNames)
    krCol = "kr_" + methodKey;
end

end
