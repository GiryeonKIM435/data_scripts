function [starts, widths, validMat] = krGridAxesForMethodType(methodType)
%krGridAxesForMethodType KrMethodRegistry から type 別グリッド軸を取得

methods = KrMethodRegistry();
types = string({methods.type});
mask = types == string(methodType);
sub = methods(mask);

if isempty(sub)
    starts = [];
    widths = [];
    validMat = false(0);
    return;
end

starts = unique([sub.gridStart]);
widths = unique([sub.gridWidth]);
validMat = false(numel(widths), numel(starts));

for i = 1:numel(sub)
    x = find(starts == sub(i).gridStart, 1);
    y = find(widths == sub(i).gridWidth, 1);
    validMat(y, x) = logical(sub(i).gridValid);
end

end
