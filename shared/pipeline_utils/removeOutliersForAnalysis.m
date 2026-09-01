function [cleanedTable, outlierLog, diag] = removeOutliersForAnalysis(tbl, basePredictors, ~, outlierCfg)
%REMOVEOUTLIERSFORANALYSIS MAD ベース外れ値除去（パイプライン共通）
%
% 外れ値判定は outlierCfg.outlierBasePredictors（既定: PredictorRegistry）を使用。
% basePredictors は outlierBasePredictors 未指定時のフォールバックのみ。

if nargin < 4 || isempty(outlierCfg)
    outlierCfg = OutlierConfig();
end
outlierCfg = applyOutlierDefaults(outlierCfg);

basePredictors = string(basePredictors(:).');
if isfield(outlierCfg, "outlierBasePredictors") && ~isempty(outlierCfg.outlierBasePredictors)
    outlierBasePredictors = string(outlierCfg.outlierBasePredictors(:)).';
else
    outlierBasePredictors = basePredictors;
end

colNames = string(tbl.Properties.VariableNames);
missingOutlierCols = outlierBasePredictors(~ismember(outlierBasePredictors, colNames));
if ~isempty(missingOutlierCols)
    warning("removeOutliersForAnalysis:MissingOutlierColumns", ...
        "外れ値基準列が master にありません（判定スキップ）: %s", ...
        strjoin(missingOutlierCols, ", "));
end

n = height(tbl);
removeFlag = false(n, 1);
outlierLog = struct("rowIndex", {}, "id", {}, "reason", {}, "variable", {}, "score", {});

yVec = tbl.yieldPointN;
[zY, ~] = madModifiedZScore(yVec);
diag.yieldZScore = zY;
if outlierCfg.modeYieldMad
    over = abs(zY) > outlierCfg.madZThreshold;
    over(~isfinite(zY)) = false;
    for idx = find(over).'
        outlierLog(end + 1) = makeLog(idx, tbl, "y MAD outlier", "yieldPointN", zY(idx)); %#ok<AGROW>
    end
    removeFlag(over) = true;
end

baseXZ = nan(n, numel(outlierBasePredictors));
for j = 1:numel(outlierBasePredictors)
    name = outlierBasePredictors(j);
    if ~ismember(name, colNames)
        continue;
    end
    [zj, ~] = madModifiedZScore(tbl{:, name});
    baseXZ(:, j) = zj;
    if outlierCfg.modeBaseXMad
        over = abs(zj) > outlierCfg.madZThreshold;
        over(~isfinite(zj)) = false;
        for idx = find(over).'
            outlierLog(end + 1) = makeLog(idx, tbl, "baseX MAD outlier", name, zj(idx)); %#ok<AGROW>
        end
        removeFlag(over) = true;
    end
end
diag.baseXZScore = baseXZ;
diag.baseXNames = outlierBasePredictors;
diag.mahaDistRobust = nan(n, 1);
diag.mahaThreshold = nan;

cleanedTable = tbl(~removeFlag, :);
diag.removeFlag = removeFlag;
diag.cfg = outlierCfg;
end

function outlierCfg = applyOutlierDefaults(outlierCfg)
defaults = struct("modeYieldMad", true, "modeBaseXMad", true, "modeRobustMaha", false, ...
    "madZThreshold", 3.5, "mahaAlpha", 0.975);
for k = fieldnames(defaults).'
    if ~isfield(outlierCfg, k{1})
        outlierCfg.(k{1}) = defaults.(k{1});
    end
end
end

function [z, info] = madModifiedZScore(x)
x = double(x);
finite = isfinite(x);
xFinite = x(finite);
if isempty(xFinite)
    z = nan(size(x)); info = struct("median", nan, "mad", nan); return;
end
med = median(xFinite);
madVal = median(abs(xFinite - med));
if madVal == 0
    z = zeros(size(x)); z(~finite) = nan;
else
    z = 0.6745 * (x - med) / madVal;
end
info = struct("median", med, "mad", madVal);
end

function entry = makeLog(rowIdx, tbl, reason, variable, score)
idVal = nan;
if ismember("id", string(tbl.Properties.VariableNames))
    idVal = tbl.id(rowIdx);
end
entry = struct("rowIndex", rowIdx, "id", idVal, "reason", string(reason), ...
    "variable", string(variable), "score", score);
end
