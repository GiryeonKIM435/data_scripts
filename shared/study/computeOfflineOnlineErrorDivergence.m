function [summaryTable, detailTable] = computeOfflineOnlineErrorDivergence( ...
    benchmark, designPerSample, methodKeys, krVariant)
%computeOfflineOnlineErrorDivergence 試料別 |e_final - e_off| の条件別平均
%
% e_off = LOOCV 絶対誤差、 e_final = Final-update 絶対誤差（予測可能試料）。

if nargin < 3 || isempty(methodKeys)
    methodKeys = string.empty(0, 1);
end
if nargin < 4 || isempty(krVariant)
    krVariant = "chord";
end
methodKeys = string(methodKeys(:));
summaryTable = table();
detailTable = table();

if isempty(benchmark) || isempty(designPerSample) || ~istable(designPerSample)
    return;
end

rows = cell(0, 4);
detailRows = cell(0, 5);
for ki = 1:numel(methodKeys)
    key = methodKeys(ki);
    offTbl = buildOfflineLoocvPerSampleTable(benchmark, key, krVariant);
    if isempty(offTbl)
        continue;
    end
    onSub = designPerSample(string(designPerSample.krMethodKey) == key, :);
    onSub = onSub(isfinite(onSub.finalUpdateErrorN), :);
    if isempty(onSub)
        continue;
    end

    [joined, offErr, onErr, absDiff] = joinOfflineOnlineErrors(offTbl, onSub);
    if isempty(joined)
        continue;
    end

    divMean = mean(absDiff, "omitnan");
    divSem = std(absDiff, "omitnan") / sqrt(nnz(isfinite(absDiff)));
    rows(end + 1, :) = {char(key), divMean, divSem, height(joined)}; %#ok<AGROW>

    for si = 1:height(joined)
        detailRows(end + 1, :) = {char(key), joined.id(si), offErr(si), onErr(si), absDiff(si)}; %#ok<AGROW>
    end
end

if ~isempty(rows)
    summaryTable = cell2table(rows, 'VariableNames', { ...
        'krMethodKey', 'errorDivergence_mean', 'errorDivergence_sem', 'nPaired'});
end
if ~isempty(detailRows)
    detailTable = cell2table(detailRows, 'VariableNames', { ...
        'krMethodKey', 'id', 'absErr_offline', 'absErr_finalUpdate', 'absDiff'});
end

end

function [joined, offErr, onErr, absDiff] = joinOfflineOnlineErrors(offTbl, onSub)
joined = table();
offErr = [];
onErr = [];
absDiff = [];

offIds = offTbl.id(:);
onIds = onSub.id(:);
[commonIds, ia, ib] = intersect(offIds, onIds, "stable");
if isempty(commonIds)
    return;
end

offErr = offTbl.absErr_offline(ia);
onErr = onSub.finalUpdateErrorN(ib);
valid = isfinite(offErr) & isfinite(onErr);
commonIds = commonIds(valid);
offErr = offErr(valid);
onErr = onErr(valid);
absDiff = abs(onErr - offErr);

joined = table(commonIds, offErr, onErr, absDiff, ...
    'VariableNames', {'id', 'absErr_offline', 'absErr_finalUpdate', 'absDiff'});
end
