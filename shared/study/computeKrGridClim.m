function clim = computeKrGridClim(summaryTable, alphaValues, methodTypes, valueField, scaleMode)
%computeKrGridClim  同一指標の全 alpha x methodType で色尺度を統一

if nargin < 5 || isempty(scaleMode)
    scaleMode = "abs";
end

vals = [];
for ai = 1:numel(alphaValues)
    alpha = alphaValues(ai);
    for mi = 1:numel(methodTypes)
        mt = string(methodTypes(mi));
        sub = summaryTable(summaryTable.alpha == alpha & string(summaryTable.methodType) == mt, :);
        if isempty(sub)
            continue;
        end
        mask = isfinite(sub.(valueField)) & logical(sub.gridValid);
        v = sub.(valueField)(mask);
        if strcmpi(scaleMode, "pct")
            v = 100 * v;
        end
        vals = [vals; v(:)]; %#ok<AGROW>
    end
end

if isempty(vals)
    if strcmpi(scaleMode, "pct")
        clim = [0, 100];
    else
        clim = [0, 1];
    end
    return;
end

vmin = min(vals);
vmax = max(vals);
if strcmpi(scaleMode, "pct")
    vmin = max(0, vmin);
    vmax = min(100, vmax);
end
if vmin == vmax
    pad = max(abs(vmin) * 0.05, 0.5);
    vmin = vmin - pad;
    vmax = vmax + pad;
    if strcmpi(scaleMode, "pct")
        vmin = max(0, vmin);
        vmax = min(100, vmax);
    end
end
clim = [vmin, vmax];

end
