function idx = resolveDiagnosticSampleIndices(cohortIds, requestedIds, fallbackFn)
%resolveDiagnosticSampleIndices 診断図用のコホートインデックスを ID から解決

if nargin < 3 || isempty(fallbackFn)
    fallbackFn = @() [];
end
if nargin < 2 || isempty(requestedIds)
    idx = fallbackFn();
    if isempty(idx)
        idx = [];
    end
    return;
end

requestedIds = double(requestedIds(:));
cohortIds = cohortIds(:);
idx = nan(numel(requestedIds), 1);
for k = 1:numel(requestedIds)
    pos = find(cohortIds == requestedIds(k), 1);
    if ~isempty(pos)
        idx(k) = pos;
    else
        warning("resolveDiagnosticSampleIndices:MissingId", ...
            "診断図: ID %d はコホートにありません。", requestedIds(k));
    end
end
idx = idx(isfinite(idx));
if isempty(idx)
    idx = fallbackFn();
end
if isempty(idx)
    idx = [];
else
    idx = idx(:)';
end

end
