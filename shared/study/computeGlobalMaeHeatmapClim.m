function clim = computeGlobalMaeHeatmapClim(q1Summary, q3Summary, cfg)
%computeGlobalMaeHeatmapClim Q1 offline MAE と Q7/Q3 stop MAE の共通色尺度
%
% cfg.paper.maeHeatmapClim が設定されていればそれを優先（論文用固定尺度）。
% online design summary では alpha が cfg.q7.designAlphaSlice（既定 0）に
% 揃えられているため、cfg.deploy.primaryAlpha では抽出しない。

if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end

if isfield(cfg, "paper") && isfield(cfg.paper, "maeHeatmapClim") ...
        && numel(cfg.paper.maeHeatmapClim) == 2 ...
        && all(isfinite(cfg.paper.maeHeatmapClim))
    clim = double(cfg.paper.maeHeatmapClim(:).');
    return;
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
    if ismember("mae_loocv", sub.Properties.VariableNames) && ismember("gridValid", sub.Properties.VariableNames)
        mask = isfinite(sub.mae_loocv) & logical(sub.gridValid);
        vals = [vals; sub.mae_loocv(mask)]; %#ok<AGROW>
    end
end

if ~isempty(q3Summary) && istable(q3Summary)
    sub = q3Summary;
    if ismember("alpha", sub.Properties.VariableNames)
        alphaTarget = resolveOnlineAlphaSlice(cfg, sub);
        if isfinite(alphaTarget)
            sub = sub(abs(sub.alpha - alphaTarget) < 1e-9, :);
        end
    end
    if ismember("methodType", sub.Properties.VariableNames)
        sub = sub(ismember(string(sub.methodType), methodTypes), :);
    end
    stopField = "finalUpdateMae";
    if ~ismember("finalUpdateMae", sub.Properties.VariableNames)
        stopField = "stopMae_success";
    end
    if ismember(stopField, sub.Properties.VariableNames) && ismember("gridValid", sub.Properties.VariableNames)
        mask = isfinite(sub.(stopField)) & logical(sub.gridValid);
        vals = [vals; sub.(stopField)(mask)]; %#ok<AGROW>
    elseif ismember(stopField, sub.Properties.VariableNames)
        mask = isfinite(sub.(stopField));
        vals = [vals; sub.(stopField)(mask)]; %#ok<AGROW>
    end
end

if isempty(vals)
    clim = [0, 1];
    return;
end

vmin = min(vals);
vmax = max(vals);
if vmin == vmax
    pad = max(abs(vmin) * 0.05, 0.5);
    vmin = vmin - pad;
    vmax = vmax + pad;
end
clim = [vmin, vmax];

end

function alphaTarget = resolveOnlineAlphaSlice(cfg, summaryTable)
alphaTarget = nan;
if isfield(cfg, "q7") && isfield(cfg.q7, "designAlphaSlice") ...
        && isfinite(cfg.q7.designAlphaSlice)
    alphaTarget = double(cfg.q7.designAlphaSlice);
    return;
end
uniq = unique(summaryTable.alpha(isfinite(summaryTable.alpha)));
if numel(uniq) == 1
    alphaTarget = uniq(1);
elseif isfield(cfg, "deploy") && isfield(cfg.deploy, "primaryAlpha")
    alphaTarget = double(cfg.deploy.primaryAlpha);
end
end
