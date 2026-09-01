function [summaryTable, metadata, sampleTable] = buildEstimateParamSummary(cfg)
%BUILDESTIMATEPARAMSUMMARY Jeffreys-success specimen parameter summary

if nargin < 1 || isempty(cfg)
    cfg = PipelineConfig();
end

catalog = estimateParamCatalog();

sFit = load(cfg.paths.tomatoWithFit, "tomatoDataWithFit", "fitResults");
fitResults = sFit.fitResults;
okMask = [fitResults.success];
successIds = [fitResults(okMask).id];
nBurgersSuccess = numel(successIds);

if nBurgersSuccess == 0
    error("buildEstimateParamSummary:NoSuccess", "No successful Jeffreys fits.");
end

keep = ismember([sFit.tomatoDataWithFit.id], successIds);
tomatoOk = sFit.tomatoDataWithFit(keep);
baseTbl = buildTomatoPredictorTable(tomatoOk);

if isfile(cfg.paths.krTable)
    sKr = load(cfg.paths.krTable, "krExport");
    krTbl = sKr.krExport;
    methods = KrMethodRegistry();
    [found, loc] = ismember(baseTbl.id, krTbl.id);
    for m = 1:numel(methods)
        key = string(methods(m).key);
        krCol = "kr_" + key;
        succCol = "krSuccess_" + key;
        vals = nan(height(baseTbl), 1);
        if ismember(krCol, krTbl.Properties.VariableNames)
            vals(found) = krTbl.(krCol)(loc(found));
            if ismember(succCol, krTbl.Properties.VariableNames)
                vals(~krTbl.(succCol)(loc(found))) = nan;
            end
        elseif key == "force_band_20_40" && ismember("kr", krTbl.Properties.VariableNames)
            vals(found) = krTbl.kr(loc(found));
            if ismember("krSuccess", krTbl.Properties.VariableNames)
                vals(~krTbl.krSuccess(loc(found))) = nan;
            end
        end
        baseTbl.(krCol) = vals;
    end
end

sampleTable = baseTbl;

nCat = height(catalog);
category = strings(nCat, 1);
parameter = strings(nCat, 1);
unit = strings(nCat, 1);
nValid = zeros(nCat, 1);
meanVal = nan(nCat, 1);
stdVal = nan(nCat, 1);
minVal = nan(nCat, 1);
maxVal = nan(nCat, 1);

for i = 1:nCat
    name = catalog.parameter(i);
    category(i) = catalog.category(i);
    parameter(i) = name;
    unit(i) = catalog.unit(i);
    if ~ismember(name, string(baseTbl.Properties.VariableNames))
        continue;
    end
    v = baseTbl{:, name};
    mask = isfinite(v);
    nValid(i) = nnz(mask);
    if nValid(i) == 0
        continue;
    end
    vv = v(mask);
    meanVal(i) = mean(vv);
    stdVal(i) = std(vv, 0);
    minVal(i) = min(vv);
    maxVal(i) = max(vv);
end

summaryTable = table(category, parameter, unit, nValid, meanVal, stdVal, minVal, maxVal, ...
    'VariableNames', {'category', 'parameter', 'unit', 'n', 'mean', 'std', 'min', 'max'});

metadata = struct();
metadata.createdAt = datetime("now");
metadata.cohort = "burgers_success";
metadata.nBurgersSuccess = nBurgersSuccess;
metadata.nSamplesInTable = height(baseTbl);
metadata.sourceFiles = struct( ...
    "tomatoWithFit", string(cfg.paths.tomatoWithFit), ...
    "krTable", string(cfg.paths.krTable));
metadata.successIds = successIds(:);

end

function catalog = estimateParamCatalog()
category = [ ...
    "measurement"; "measurement"; "measurement"; "measurement"; ...
    "yield"; ...
    "burgers"; "burgers"; "burgers"; ...
    "creep"; "creep"; "creep"; "creep"; "creep"];
parameter = [ ...
    "weight"; "x"; "y"; "z"; ...
    "yieldPointN"; ...
    "k2"; "c1"; "c2"; ...
    "t50"; "t95"; "vInit"; "vLong"; "delayedRatio"];
unit = [ ...
    "g"; "mm"; "mm"; "mm"; ...
    "N"; ...
    "N/mm"; "N·s/mm"; "N·s/mm"; ...
    "s"; "s"; "mm/s"; "mm/s"; "-"];

methods = KrMethodRegistry();
for m = 1:numel(methods)
    category(end + 1, 1) = "kr"; %#ok<AGROW>
    parameter(end + 1, 1) = "kr_" + string(methods(m).key); %#ok<AGROW>
    unit(end + 1, 1) = "N/mm"; %#ok<AGROW>
end
catalog = table(category, parameter, unit);
end
