function clim = computeGlobalRelErrorHeatmapClim(q1Summary, q3Summary, cfg)
%computeGlobalRelErrorHeatmapClim Q1 LOOCV と Q3 stop rel error の共通色尺度 [%]

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 2
    q3Summary = [];
end

vals = [];
krVariant = string(cfg.deploy.krVariant);
methodTypes = activeKrMethodTypes(cfg);

if ~isempty(q1Summary) && istable(q1Summary)
    sub = q1Summary;
    if ismember("variant", sub.Properties.VariableNames)
        sub = sub(string(sub.variant) == krVariant, :);
    end
    if ismember("methodType", sub.Properties.VariableNames)
        sub = sub(ismember(string(sub.methodType), methodTypes), :);
    end
    if ismember("relativeError_loocv", sub.Properties.VariableNames) && ismember("gridValid", sub.Properties.VariableNames)
        mask = isfinite(sub.relativeError_loocv) & logical(sub.gridValid);
        vals = [vals; 100 * sub.relativeError_loocv(mask)]; %#ok<AGROW>
    end
end

if ~isempty(q3Summary) && istable(q3Summary)
    sub = q3Summary;
    if ismember("methodType", sub.Properties.VariableNames)
        sub = sub(ismember(string(sub.methodType), methodTypes), :);
    end
    relField = "relativeStopError_success_mean";
    if ismember("relativeStopError_success_bootMean_b5000", sub.Properties.VariableNames)
        relField = "relativeStopError_success_bootMean_b5000";
    end
    if ismember(relField, sub.Properties.VariableNames) && ismember("gridValid", sub.Properties.VariableNames)
        mask = isfinite(sub.(relField)) & logical(sub.gridValid);
        vals = [vals; 100 * sub.(relField)(mask)]; %#ok<AGROW>
    end
end

clim = finalizePctHeatmapClim(vals);

end

function clim = finalizePctHeatmapClim(vals)
if isempty(vals)
    clim = [0, 100];
    return;
end

vmin = min(vals);
vmax = max(vals);
vmin = max(0, vmin);
vmax = min(100, vmax);
if vmin == vmax
    pad = max(abs(vmin) * 0.05, 0.5);
    vmin = max(0, vmin - pad);
    vmax = min(100, vmax + pad);
end
clim = [vmin, vmax];

end
