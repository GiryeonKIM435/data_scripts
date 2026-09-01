function idx = findKrGridCellIndex(krMethodKey, methodType)
%findKrGridCellIndex krMethodKey のグリッドセル [yi, xi] を返す

idx = [];
if nargin < 2 || strlength(string(methodType)) == 0 ...
        || strlength(string(krMethodKey)) == 0
    return;
end

methods = KrMethodRegistry();
mdef = lookupKrMethodRegistry(krMethodKey, methods);
if string(mdef.type) ~= string(methodType)
    return;
end

[starts, widths, ~] = krGridAxesForMethodType(methodType);
xi = find(starts == mdef.gridStart, 1);
yi = find(widths == mdef.gridWidth, 1);
if isempty(xi) || isempty(yi)
    return;
end
idx = [yi, xi];

end
