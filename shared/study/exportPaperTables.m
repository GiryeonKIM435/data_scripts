function exportPaperTables(tbl, basePath, caption)
%exportPaperTables CSV と簡易 LaTeX 表を出力

if nargin < 3
    caption = "Results";
end

writetable(tbl, char(basePath + ".csv"));

fid = fopen(char(basePath + ".tex"), "w");
if fid < 0
    warning("exportPaperTables:WriteFailed", "LaTeX 書き込み失敗: %s", basePath);
    return;
end

layout = paperTableLayout(tbl);

fprintf(fid, "%% %s\n", caption);
fprintf(fid, "\\begin{table}[htbp]\n\\centering\n");
fprintf(fid, "\\caption{%s}\n", caption);
fprintf(fid, "\\begin{tabular}{%s}\n", layout.latexColSpec);

hdr = strings(1, width(tbl));
for c = 1:width(tbl)
    name = texEscape(char(string(tbl.Properties.VariableNames(c))));
    if layout.colAlign(c) == "right"
        hdr(c) = sprintf("\\multicolumn{1}{c}{%s}", name);
    else
        hdr(c) = name;
    end
end
fprintf(fid, "%s \\\\\n", strjoin(hdr, " & "));
fprintf(fid, "\\hline\n");

for r = 1:height(tbl)
    cells = strings(1, width(tbl));
    for c = 1:width(tbl)
        cells(c) = texEscape(char(layout.cellText(r, c)));
    end
    fprintf(fid, "%s \\\\\n", strjoin(cells, " & "));
end

fprintf(fid, "\\end{tabular}\n\\end{table}\n");
fclose(fid);
end

function s = texEscape(s)
s = strrep(s, "_", "\\_");
s = strrep(s, "%", "\\%");
s = strrep(s, char(177), "$\\pm$");
s = strrep(s, "R^2", "$R^2$");
end
