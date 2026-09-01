function ref = resolveKrHeatmapReference(pairTable, summarySub, metricField)
%resolveKrHeatmapReference Wilcoxon 比較の参照方式キーを返す

ref = struct("methodKey", "", "variant", "");
if nargin < 3 || strlength(string(metricField)) == 0
    metricField = "mae_loocv";
end

if ~isempty(pairTable) && height(pairTable) > 0 ...
        && ismember("referenceMethod", pairTable.Properties.VariableNames)
    ref.methodKey = toSafeChar(pairTable.referenceMethod(1));
    if ismember("referenceVariant", pairTable.Properties.VariableNames)
        ref.variant = toSafeChar(pairTable.referenceVariant(1));
    end
    return;
end

if isempty(summarySub) || height(summarySub) == 0 ...
        || ~ismember(metricField, summarySub.Properties.VariableNames)
    return;
end

finiteMask = isfinite(summarySub.(metricField));
if ~any(finiteMask)
    return;
end
sub = summarySub(finiteMask, :);
[~, idx] = min(sub.(metricField));
ref.methodKey = toSafeChar(sub.krMethodKey(idx));
if ismember("variant", sub.Properties.VariableNames)
    ref.variant = toSafeChar(sub.variant(idx));
end

end

function out = toSafeChar(v)
%toSafeChar missing / empty を空文字に正規化
try
    if ismissing(v)
        out = "";
        return;
    end
catch
    % ismissing 非対応型はそのまま変換を試みる
end
s = string(v);
if isempty(s) || all(ismissing(s))
    out = "";
else
    out = char(s(1));
end
end
