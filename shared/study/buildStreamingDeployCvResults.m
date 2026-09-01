function cvByRow = buildStreamingDeployCvResults(perSampleTable, summaryRows, alpha)
%buildStreamingDeployCvResults per-sample Final-update 誤差を compare 用 cv 構造に変換
%
% summaryRows: height = nMethods の krMethodKey 等を含む table
% pairingMode mutualFinite 用に ids + absErrors を保持

cvByRow = cell(height(summaryRows), 1);
if isempty(perSampleTable) || isempty(summaryRows)
    return;
end

if ismember("alpha", perSampleTable.Properties.VariableNames) && isfinite(alpha)
    sub = perSampleTable(perSampleTable.alpha == alpha, :);
else
    sub = perSampleTable;
end
% Design-α 既存結果で alpha 列が fold 固有値のまま残っている場合、
% slice フィルタが空になるので methodKey だけで紐づける。
if isempty(sub)
    sub = perSampleTable;
end

for ri = 1:height(summaryRows)
    key = string(summaryRows.krMethodKey(ri));
    msub = sub(string(sub.krMethodKey) == key, :);
    if isempty(msub)
        cvByRow{ri} = struct("ids", [], "absErrors", [], "yTrue", [], "yPred", []);
        continue;
    end
    evalMask = isfinite(msub.finalUpdateErrorN);
    ids = msub.id(evalMask);
    absErrors = msub.finalUpdateErrorN(evalMask);
    cvByRow{ri} = struct( ...
        "ids", ids(:), ...
        "absErrors", absErrors(:), ...
        "yTrue", msub.yTrue(evalMask), ...
        "yPred", msub.y_hat_finalUpdate(evalMask));
end

end
