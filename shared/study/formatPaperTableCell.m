function s = formatPaperTableCell(val)
%formatPaperTableCell 表プレビュー・LaTeX 用セル文字列

if iscell(val)
    if isempty(val) || (numel(val) == 1 && (isempty(val{1}) || (isnumeric(val{1}) && ~isfinite(val{1}))))
        s = "";
        return;
    end
    val = val{1};
end
if isstring(val) || ischar(val)
    s = char(string(val));
    return;
end
if isnumeric(val) && isscalar(val)
    if ~isfinite(val)
        s = "";
    elseif abs(val) < 0.01 && val ~= 0
        s = sprintf("%.2e", val);
    else
        s = sprintf("%.4g", val);
    end
else
    s = char(string(val));
end

end
