function crossSummary = buildQ5CrossTrackSummary(offlineTrack, onlineTrack, cfg, outDir)
%buildQ5CrossTrackSummary Track-OFF LOOCV vs Track-ON Online の横断比較表

refCase = cfg.q5.referenceCaseId;
caseOrder = getQ5ModelCaseOrder(cfg);
rows = cell(0, 14);

offCmp = table();
if isfield(offlineTrack, "caseStats") && isfield(offlineTrack.caseStats, "offline")
    offCmp = offlineTrack.caseStats.offline;
end
onCmp = table();
if isfield(onlineTrack, "caseStats") && isfield(onlineTrack.caseStats, "online")
    onCmp = onlineTrack.caseStats.online;
end

for ci = 1:numel(caseOrder)
    cid = caseOrder(ci);
    if cid == refCase
        continue;
    end
    offRow = lookupComparisonRow(offCmp, cid);
    onRow = lookupComparisonRow(onCmp, cid);
    rows(end + 1, :) = {char(cid), ...
        getFieldOrNaN(offRow, "deltaMae"), getFieldOrNaN(offRow, "ciDeltaMaeLo"), ...
        getFieldOrNaN(offRow, "ciDeltaMaeHi"),         getFieldOrNaN(offRow, "qValueBH"), ...
        getFieldOrNaNPrefer(offRow, ["pWilcoxon", "pBootstrap"]), ...
        getFieldOrNaN(onRow, "deltaMae"), getFieldOrNaN(onRow, "ciDeltaMaeLo"), ...
        getFieldOrNaN(onRow, "ciDeltaMaeHi"), getFieldOrNaN(onRow, "qValueBH"), ...
        getFieldOrNaNPrefer(onRow, ["pWilcoxon", "pBootstrap"]), ...
        char(offlineTrack.krMethodKey), char(onlineTrack.krMethodKey), char(refCase)}; %#ok<AGROW>
end

if isempty(rows)
    crossSummary = table();
    return;
end

crossSummary = cell2table(rows, 'VariableNames', { ...
    'caseId', 'deltaMae_offlineLoocv', 'ciDeltaMaeLo_offline', 'ciDeltaMaeHi_offline', ...
    'qValueBH_offline', 'pBootstrap_offline', ...
    'deltaMae_onlineDeploy', 'ciDeltaMaeLo_online', 'ciDeltaMaeHi_online', ...
    'qValueBH_online', 'pBootstrap_online', ...
    'offlineKrMethodKey', 'onlineKrMethodKey', 'referenceCase'});

if strlength(string(outDir)) > 0
    writetable(crossSummary, fullfile(outDir, "q5_cross_track_summary.csv"));
end

end

function row = lookupComparisonRow(tbl, caseId)
row = [];
if isempty(tbl)
    return;
end
idx = find(string(tbl.model) == string(caseId), 1);
if isempty(idx)
    return;
end
row = tbl(idx, :);
end

function v = getFieldOrNaN(row, fieldName)
v = nan;
if isempty(row) || ~ismember(fieldName, row.Properties.VariableNames)
    return;
end
v = row.(fieldName);
if isempty(v)
    v = nan;
end
end

function v = getFieldOrNaNPrefer(row, fieldNames)
v = nan;
fieldNames = string(fieldNames(:));
for i = 1:numel(fieldNames)
    v = getFieldOrNaN(row, fieldNames(i));
    if isfinite(v)
        return;
    end
end
end
