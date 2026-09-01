function clim = computeGlobalStopR2HeatmapClim(q3Summary, cfg)
%computeGlobalStopR2HeatmapClim Q3 stop R² ヒートマップの共通色尺度

if nargin < 2 || isempty(cfg)
    cfg = PaperStudyConfig();
end

vals = [];
methodTypes = activeKrMethodTypes(cfg);

if ~isempty(q3Summary) && istable(q3Summary)
    sub = q3Summary;
    if ismember("methodType", sub.Properties.VariableNames)
        sub = sub(ismember(string(sub.methodType), methodTypes), :);
    end
    if ismember("stopR2_success", sub.Properties.VariableNames) ...
            && ismember("gridValid", sub.Properties.VariableNames)
        mask = isfinite(sub.stopR2_success) & logical(sub.gridValid);
        vals = [vals; sub.stopR2_success(mask)]; %#ok<AGROW>
    end
end

if isempty(vals)
    clim = [0, 1];
    return;
end

vmin = max(0, min(vals));
vmax = max(vals);
if vmin == vmax
    pad = max(0.05, abs(vmax) * 0.05);
    vmin = max(0, vmin - pad);
    vmax = min(1, vmax + pad);
end
clim = [vmin, vmax];

end
