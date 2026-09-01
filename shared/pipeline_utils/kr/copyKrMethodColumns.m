function [krValsLs, krValsChord, success, fitTier, fitR2, nBand] = ...
    copyKrMethodColumns(key, oldExport, newIds)
%copyKrMethodColumns 既存 export から方式列を newIds 順に複写

key = string(key);
n = numel(newIds);
krValsLs = nan(n, 1);
krValsChord = nan(n, 1);
success = false(n, 1);
fitTier = zeros(n, 1);
fitR2 = nan(n, 1);
nBand = nan(n, 1);

if isequal(oldExport.id, newIds)
    idx = (1:n)';
else
    [~, idx] = ismember(newIds, oldExport.id);
end

krLsCol = "krLs_" + key;
krChordCol = "krChord_" + key;
succCol = "krSuccess_" + key;
tierCol = "krFitTier_" + key;
r2Col = "krFitR2_" + key;
nCol = "krNBand_" + key;

krValsLs = oldExport.(krLsCol)(idx);
krValsChord = oldExport.(krChordCol)(idx);
success = oldExport.(succCol)(idx);
fitTier = oldExport.(tierCol)(idx);
fitR2 = oldExport.(r2Col)(idx);
nBand = oldExport.(nCol)(idx);

krValsLs = krValsLs(:);
krValsChord = krValsChord(:);
success = success(:);
fitTier = fitTier(:);
fitR2 = fitR2(:);
nBand = nBand(:);

end
