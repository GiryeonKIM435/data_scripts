function nondiffMask95 = buildKrWilcoxonNondiffMask(pairTable, methodType, referenceKey, opts)
%buildKrWilcoxonNondiffMask BH補正後 q 値に基づく非有意セル mask
%
% q >= fdrAlpha95（既定 0.05）を「基準条件との差が統計学的に有意でない」
% セルとして返す単一マスク。
%
% opts.alpha            : online 用（pairTable を alpha で絞る）
% opts.referenceVariant : variant 列がある場合
% opts.fdrAlpha         : 後方互換。指定時は fdrAlpha95 に使う
% opts.fdrAlpha95       : 既定 0.05

if nargin < 4 || isempty(opts)
    opts = struct();
end
if isfield(opts, "fdrAlpha") && ~isempty(opts.fdrAlpha) && isfinite(opts.fdrAlpha)
    opts.fdrAlpha95 = opts.fdrAlpha;
end
if ~isfield(opts, "fdrAlpha95") || isempty(opts.fdrAlpha95)
    opts.fdrAlpha95 = 0.05;
end
if ~isfield(opts, "alpha")
    opts.alpha = nan;
end
if ~isfield(opts, "referenceVariant")
    opts.referenceVariant = "";
end

[~, ~, validMat] = krGridAxesForMethodType(methodType);
nondiffMask95 = false(size(validMat));

if isempty(pairTable) || height(pairTable) == 0
    return;
end

sub = pairTable;
if isfinite(opts.alpha) && ismember("alpha", sub.Properties.VariableNames)
    sub = sub(sub.alpha == opts.alpha, :);
end
if isempty(sub)
    return;
end

refKey = string(referenceKey);
sub = sub(string(sub.referenceMethod) == refKey, :);
if strlength(string(opts.referenceVariant)) > 0 ...
        && ismember("referenceVariant", sub.Properties.VariableNames)
    sub = sub(string(sub.referenceVariant) == string(opts.referenceVariant), :);
end
if isempty(sub) || ~ismember("qValueBH", sub.Properties.VariableNames)
    return;
end

alpha95 = double(opts.fdrAlpha95);

for ri = 1:height(sub)
    qVal = sub.qValueBH(ri);
    if ~isfinite(qVal)
        continue;
    end
    cmpKey = string(sub.comparisonMethod(ri));
    idx = findKrGridCellIndex(cmpKey, methodType);
    if isempty(idx)
        continue;
    end
    yi = idx(1);
    xi = idx(2);
    if yi < 1 || yi > size(nondiffMask95, 1) || xi < 1 || xi > size(nondiffMask95, 2)
        continue;
    end
    if qVal >= alpha95
        nondiffMask95(yi, xi) = true;
    end
end

end
