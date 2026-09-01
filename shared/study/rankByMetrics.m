function [sortedTbl, bestRowIdx] = rankByMetrics(tbl, cfg)
%rankByMetrics MAE -> RMSE -> R2 の多段ソート

if nargin < 2 || isempty(cfg)
    cfg = PaperStudyConfig();
end

metrics = metricRankOrder(cfg);
sortedTbl = tbl;
for i = 1:numel(metrics)
    m = metrics(i);
    col = metricColumnName(m, cfg);
    if ~ismember(col, sortedTbl.Properties.VariableNames)
        error("rankByMetrics:MissingColumn", "列がありません: %s", col);
    end
    dir = metricSortDirection(m, cfg);
    sortedTbl = sortrows(sortedTbl, col, dir, "MissingPlacement", "last");
end
bestRowIdx = 1;

end

function metrics = metricRankOrder(cfg)
metrics = [string(cfg.metrics.primary); string(cfg.metrics.secondary(:))];
end

function col = metricColumnName(metric, cfg)
suffix = cfg.metrics.loocvSuffix;
col = string(metric) + suffix;
end

function dir = metricSortDirection(metric, cfg)
key = char(metric);
if isfield(cfg.metrics.rankDirection, key)
    dir = cfg.metrics.rankDirection.(key);
else
    dir = "ascend";
end
end
