function figSize = computeCompactHeatmapSize(starts, widths)
%computeCompactHeatmapSize  小さいグリッド向けのコンパクト figure サイズ
%
% 論文貼付向けにキャンバスを約 85% に縮小する（フォントサイズは変更しない）。

scale = 0.85;
cellW = round(72 * scale);
cellH = round(52 * scale);
padW = round(220 * scale);
padH = round(160 * scale);
figSize = [padW + cellW * max(1, numel(starts)), padH + cellH * max(1, numel(widths))];
figSize = [min(round(760 * scale), max(round(420 * scale), figSize(1))), ...
    min(round(480 * scale), max(round(300 * scale), figSize(2)))];

end
