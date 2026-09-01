function val = extractTomatoPredictorValue(item, spec)
%extractTomatoPredictorValue tomato 構造体から説明変数を1つ抽出

val = nan;
if nargin < 2 || ~isstruct(spec) || ~isfield(spec, "source")
    return;
end

switch string(spec.source)
    case "item"
        if isfield(spec, "field")
            val = getfieldOrDefault(item, char(spec.field), nan);
        end
    case "size"
        sizeInfo = getfieldOrDefault(item, "size", struct());
        if isfield(spec, "field")
            val = getfieldOrDefault(sizeInfo, char(spec.field), nan);
        end
    case "burgersFit"
        bf = getfieldOrDefault(item, "burgersFit", struct());
        if isfield(spec, "field")
            val = getfieldOrDefault(bf, char(spec.field), nan);
        end
    case "derived"
        if isfield(spec, "field") && ismember(string(spec.field), ["d_eq", "r_eq"])
            sizeInfo = getfieldOrDefault(item, "size", struct());
            sx = getfieldOrDefault(sizeInfo, "x", nan);
            sy = getfieldOrDefault(sizeInfo, "y", nan);
            sz = getfieldOrDefault(sizeInfo, "z", nan);
            if string(spec.field) == "d_eq"
                val = computeEquivalentDiameter(sx, sy, sz);
            else
                val = computeEquivalentRadius(sx, sy, sz);
            end
        end
end

end

function v = getfieldOrDefault(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    v = s.(fieldName);
else
    v = defaultValue;
end
end
