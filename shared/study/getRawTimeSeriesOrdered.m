function ts = getRawTimeSeriesOrdered(artifacts, sampleId, timeOrder)
%getRawTimeSeriesOrdered 試料の (def, force, sec) を時系列順で返す

if nargin < 3 || isempty(timeOrder)
    timeOrder = "sec_asc";
end

sampleId = double(sampleId);
if isfield(artifacts, "timeSeriesCache") && isKey(artifacts.timeSeriesCache, sampleId)
    ts = artifacts.timeSeriesCache(sampleId);
    return;
end

if ~isKey(artifacts.rawMap, sampleId)
    error("getRawTimeSeriesOrdered:MissingSample", "試料 %d の生データがありません。", sampleId);
end

rawItem = artifacts.rawMap(sampleId);
y = rawItem.yield;
def = y.deformation(:);
force = y.force(:);
if isfield(y, "sec")
    sec = y.sec(:);
else
    sec = (1:numel(def)).';
end

valid = isfinite(def) & isfinite(force);
def = def(valid);
force = force(valid);
sec = sec(valid);
if isempty(def)
    error("getRawTimeSeriesOrdered:EmptySeries", "試料 %d の有効点がありません。", sampleId);
end

switch string(timeOrder)
    case "sec_asc"
        [sec, ord] = sort(sec, "ascend");
    case "index"
        ord = (1:numel(def)).';
    case "def_asc"
        [~, ord] = sort(def, "ascend");
        sec = sec(ord);
    otherwise
        error("getRawTimeSeriesOrdered:BadOrder", "未知の timeOrder: %s", timeOrder);
end
def = def(ord);
force = force(ord);
if string(timeOrder) ~= "index"
    sec = sec(ord);
end

ts = struct();
ts.def = def;
ts.force = force;
ts.sec = sec;
ts.n = numel(def);

if isfield(artifacts, "timeSeriesCache")
    artifacts.timeSeriesCache(sampleId) = ts;
end

end
