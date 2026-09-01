function layout = resolveKrHeatmapLayout(prefix, starts, widths)
%resolveKrHeatmapLayout ヒートマップの軸ラベル・サイズ

layout = struct();
layout.figSize = [920, 560];
layout.compactText = false;
layout.xLabel = "Start";
layout.yLabel = "Band width";

if prefix == "force_abs" || prefix == "force_trail"
    layout.figSize = computeCompactHeatmapSize(starts, widths);
    layout.compactText = true;
    layout.xLabel = 'Offset \it\xi\rm (N)';
    layout.yLabel = 'Width \itW\rm (N)';
end

end
