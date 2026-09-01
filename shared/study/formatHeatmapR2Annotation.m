function txt = formatHeatmapR2Annotation(r2Val)
%formatHeatmapR2Annotation ヒートマップ注記用 R^2 行（R は斜体、TeX）

txt = sprintf('{\\it R}^2=%.2f', r2Val);

end
