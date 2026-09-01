function [valueMat, semMat, starts, widths, validMat] = buildKrGridMatrices(sub, valueField, semField, methodType)
%buildKrGridMatrices  gridStart x gridWidth の値行列を構築
% methodType を指定すると KrMethodRegistry の現行グリッド軸を使用

if nargin < 3
    semField = "";
end
if nargin < 4
    methodType = "";
end

if isempty(sub)
    valueMat = nan(0);
    semMat = nan(0);
    starts = [];
    widths = [];
    validMat = false(0);
    return;
end

useRegistryAxes = strlength(string(methodType)) > 0;
if useRegistryAxes
    [starts, widths, validMat] = krGridAxesForMethodType(methodType);
else
    starts = unique(sub.gridStart);
    widths = unique(sub.gridWidth);
    validMat = false(numel(widths), numel(starts));
end

valueMat = nan(numel(widths), numel(starts));
semMat = nan(numel(widths), numel(starts));
hasSem = strlength(string(semField)) > 0 ...
    && ismember(semField, sub.Properties.VariableNames);

for i = 1:height(sub)
    x = find(starts == sub.gridStart(i), 1);
    y = find(widths == sub.gridWidth(i), 1);
    if isempty(x) || isempty(y)
        continue;
    end
    if ~useRegistryAxes
        validMat(y, x) = logical(sub.gridValid(i));
    end
    valueMat(y, x) = sub.(valueField)(i);
    if hasSem
        semMat(y, x) = sub.(semField)(i);
    end
end

if useRegistryAxes
    valueMat(~validMat) = nan;
    if hasSem
        semMat(~validMat) = nan;
    end
else
    valueMat(~validMat) = nan;
    if hasSem
        semMat(~validMat) = nan;
    end
end

end
