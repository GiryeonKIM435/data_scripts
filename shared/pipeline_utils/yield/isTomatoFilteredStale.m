function stale = isTomatoFilteredStale(filteredMatPath, cfg)
%isTomatoFilteredStale tomato_filtered.mat が零点調整設定と不一致か

stale = false;
if nargin < 1 || ~isfile(filteredMatPath)
    stale = true;
    return;
end

if nargin < 2 || isempty(cfg)
    cfg = PipelineConfig();
end

currentFp = yieldZeroAdjustFingerprint(cfg);
s = load(filteredMatPath, "metadataFiltered");
if ~isfield(s, "metadataFiltered")
    stale = true;
    return;
end

meta = s.metadataFiltered;
if ~isfield(meta, "zeroAdjustFingerprint") || ...
        string(meta.zeroAdjustFingerprint) ~= string(currentFp)
    stale = true;
end

end
