function txt = formatPForDisplay(p)
%formatPForDisplay 図表用 p 値文字列

if ~isfinite(p)
    txt = "p=NA";
    return;
end
if p < 0.001
    txt = "p<0.001";
elseif p < 0.01
    txt = sprintf("p=%.3f", p);
else
    txt = sprintf("p=%.2f", p);
end
txt = string(txt);
end
