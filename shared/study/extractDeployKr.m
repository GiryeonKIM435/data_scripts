function kr = extractDeployKr(rr, krVariant)
%extractDeployKr fitKrBand 結果からデプロイ用 kr を抽出

if nargin < 2 || isempty(krVariant)
    krVariant = "chord";
end

kr = nan;
if ~rr.success
    return;
end

switch string(krVariant)
    case "chord"
        field = "krChord_N_per_mm";
    case "ls"
        field = "kr_N_per_mm";
    otherwise
        error("extractDeployKr:BadVariant", "未知の krVariant: %s", krVariant);
end

if isfield(rr, field) && isfinite(rr.(field)) && rr.(field) > 0
    kr = rr.(field);
end

end
