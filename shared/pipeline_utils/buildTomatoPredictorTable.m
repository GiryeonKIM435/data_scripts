function tbl = buildTomatoPredictorTable(tomatoDataWithFit)
%BUILDTOMATOPREDICTORTABLE Build summary parameter table from Jeffreys fits

reg = PredictorRegistry();
mapNames = string(fieldnames(reg.predictorFieldMap));
n = numel(tomatoDataWithFit);

id = nan(n, 1);
yieldPointN = nan(n, 1);
predData = struct();
for k = 1:numel(mapNames)
    predData.(mapNames(k)) = nan(n, 1);
end

for i = 1:n
    item = tomatoDataWithFit(i);
    id(i) = getfieldOrDefault(item, "id", nan);
    yd = getfieldOrDefault(item, "yieldDropThreshold", struct());
    if getfieldOrDefault(yd, "hasYield", false)
        yieldPointN(i) = getfieldOrDefault(yd, "force", nan);
    end
    for k = 1:numel(mapNames)
        name = mapNames(k);
        spec = reg.predictorFieldMap.(name);
        predData.(name)(i) = extractTomatoPredictorValue(item, spec);
    end
end

cols = cell(2 + numel(mapNames), 1);
cols{1} = id;
cols{2} = yieldPointN;
for k = 1:numel(mapNames)
    cols{2 + k} = predData.(mapNames(k));
end
varNames = [string({"id", "yieldPointN"}), mapNames(:).'];
tbl = table(cols{:}, 'VariableNames', cellstr(varNames));
end

function v = getfieldOrDefault(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName)
    v = s.(fieldName);
else
    v = defaultValue;
end
end
