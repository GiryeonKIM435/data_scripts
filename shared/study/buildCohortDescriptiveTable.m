function descTbl = buildCohortDescriptiveTable(cohort, cfg)
%buildCohortDescriptiveTable 記述統計用の試料属性表

n = cohort.n;
ids = cohort.ids(:);
base = cohort.predictorTable(:, ["yieldPointN", "c1", "c2", "k2"]);
d_eq = nan(n, 1);
if ismember("d_eq", string(cohort.predictorTable.Properties.VariableNames))
    d_eq = cohort.predictorTable.d_eq(:);
elseif ismember("r_eq", string(cohort.predictorTable.Properties.VariableNames))
    % 旧コホート互換: r_eq (半径) → d_eq (直径)
    d_eq = 2 * cohort.predictorTable.r_eq(:);
end

weight = nan(n, 1);
x = nan(n, 1);
y = nan(n, 1);
z = nan(n, 1);

sRaw = load(cfg.paths.tomatoDataset, "tomatoData");
rawMap = containers.Map("KeyType", "double", "ValueType", "any");
for i = 1:numel(sRaw.tomatoData)
    rawMap(sRaw.tomatoData(i).id) = sRaw.tomatoData(i);
end

for i = 1:n
    if ~rawMap.isKey(ids(i))
        continue;
    end
    item = rawMap(ids(i));
    if isfield(item, "weight") && isfinite(item.weight)
        weight(i) = item.weight;
    end
    if isfield(item, "size") && isstruct(item.size)
        if isfield(item.size, "x") && isfinite(item.size.x)
            x(i) = item.size.x;
        end
        if isfield(item.size, "y") && isfinite(item.size.y)
            y(i) = item.size.y;
        end
        if isfield(item.size, "z") && isfinite(item.size.z)
            z(i) = item.size.z;
        end
    end
end

descTbl = [base, table(x, y, z, weight, d_eq)];

end
