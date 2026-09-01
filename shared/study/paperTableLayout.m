function layout = paperTableLayout(tbl)
%paperTableLayout 列幅・水平揃え（項目=中央、数値=右）

nCols = width(tbl);
colNames = string(tbl.Properties.VariableNames);
nRows = height(tbl);

cellText = strings(nRows, nCols);
for r = 1:nRows
    for c = 1:nCols
        cellText(r, c) = string(formatPaperTableCell(tbl{r, c}));
    end
end

colAlign = strings(1, nCols);
colWeights = zeros(1, nCols);
pmChar = string(char(177));

for c = 1:nCols
    headerLen = strlength(colNames(c));
    dataLens = strlength(cellText(:, c));
    dataLens(dataLens == 0) = 0;
    colWeights(c) = max([headerLen, max(dataLens), 1]);

    if c == 1 || ~isPaperNumericColumn(cellText(:, c))
        colAlign(c) = "center";
    else
        colAlign(c) = "right";
    end
end

colWeights = colWeights + 1;
layout = struct();
layout.colNames = colNames;
layout.colAlign = colAlign;
layout.colWeights = colWeights;
layout.cellText = cellText;
layout.latexColSpec = composeLatexColSpec(colAlign);

end

function tf = isPaperNumericColumn(colCells)
colCells = string(colCells);
nonEmpty = colCells(strlength(strtrim(colCells)) > 0);
if isempty(nonEmpty)
    tf = false;
    return;
end
tf = all(arrayfun(@isPaperNumericCell, nonEmpty));
end

function tf = isPaperNumericCell(txt)
s = strtrim(char(txt));
if isempty(s)
    tf = false;
    return;
end
pm = char(177);
patterns = string({ ...
    ['^[-+]?\d+(\.\d+)?([' pm '][-+]?\d+(\.\d+)?)?$'], ...
    '^[-+]?\d+(\.\d+)?$', ...
    '^[-+]?\d+(\.\d+)?%$'});
tf = false;
for i = 1:numel(patterns)
    if ~isempty(regexp(s, patterns(i), "once"))
        tf = true;
        return;
    end
end
end

function spec = composeLatexColSpec(colAlign)
chars = strings(1, numel(colAlign));
for i = 1:numel(colAlign)
    if colAlign(i) == "right"
        chars(i) = "r";
    else
        chars(i) = "c";
    end
end
spec = char(strjoin(chars, ""));
end
