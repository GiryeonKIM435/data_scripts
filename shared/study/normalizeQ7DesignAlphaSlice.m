function [perSample, summary] = normalizeQ7DesignAlphaSlice(perSample, summary, designSlice)
%normalizeQ7DesignAlphaSlice Design-α 結果の alpha 列を共通 slice に揃える
%
% fold 固有の α は alphaDesign に残し、Wilcoxon 比較・ヒートマップ用の
% alpha 列だけを designSlice（既定 0）へ正規化する。
% 既存 mat / CSV で per-sample の alpha が未正規化の場合の再利用にも使う。

if nargin < 3 || isempty(designSlice) || ~isfinite(designSlice)
    designSlice = 0;
end
designSlice = double(designSlice);

if ~isempty(perSample) && istable(perSample) && height(perSample) > 0 ...
        && ismember("alpha", perSample.Properties.VariableNames)
    if ~ismember("alphaDesign", perSample.Properties.VariableNames)
        perSample.alphaDesign = perSample.alpha;
    else
        missingDesign = ~isfinite(perSample.alphaDesign);
        if any(missingDesign)
            perSample.alphaDesign(missingDesign) = perSample.alpha(missingDesign);
        end
    end
    % alpha がすでに slice と一致していなければ正規化
    if ~all(perSample.alpha == designSlice)
        perSample.alpha = designSlice * ones(height(perSample), 1);
    end
end

if ~isempty(summary) && istable(summary) && height(summary) > 0 ...
        && ismember("alpha", summary.Properties.VariableNames)
    if ~ismember("alphaDesign", summary.Properties.VariableNames)
        summary.alphaDesign = summary.alpha;
    else
        missingDesign = ~isfinite(summary.alphaDesign);
        if any(missingDesign)
            summary.alphaDesign(missingDesign) = summary.alpha(missingDesign);
        end
    end
    if ~all(summary.alpha == designSlice)
        summary.alpha = designSlice * ones(height(summary), 1);
    end
end

end
