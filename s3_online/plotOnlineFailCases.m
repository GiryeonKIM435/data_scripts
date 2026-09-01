function outPaths = plotOnlineFailCases(cfg, cohort, designPerSample, outDir)
%plotOnlineFailCases force_s00_w30 / force_s05_w30 の安全停止失敗例を時系列描画
%
% 既存の一例図と同じ形式（Measured / Predicted / Stop threshold ŷ/α / Stop time）で、
% outcome ~= "success" の全試料を outDir/fail_cases/ に出力する。

outPaths = strings(0, 1);
if isempty(designPerSample)
    return;
end

failDir = fullfile(outDir, "fail_cases");
if ~isfolder(failDir)
    mkdir(failDir);
end

methodKeys = ["force_s00_w30"; "force_s05_w30"];
hasOutcome = ismember("outcome", designPerSample.Properties.VariableNames);
if ~hasOutcome
    warning("plotOnlineFailCases:NoOutcome", "designPerSample に outcome 列がありません。");
    return;
end

for mi = 1:numel(methodKeys)
    mk = methodKeys(mi);
    sub = designPerSample(string(designPerSample.krMethodKey) == mk ...
        & string(designPerSample.outcome) ~= "success", :);
    if isempty(sub)
        fprintf("4.3 online fail cases [%s]: none\n", mk);
        continue;
    end
    fprintf("4.3 online fail cases [%s]: n=%d\n", mk, height(sub));
    for ri = 1:height(sub)
        sampleId = sub.id(ri);
        outcome = string(sub.outcome(ri));
        alphaDesign = resolveFailCaseAlpha(sub(ri, :));
        fprintf("  - id=%d outcome=%s alpha_0.95=%.3f\n", sampleId, outcome, alphaDesign);
        if ~isfinite(alphaDesign)
            warning("plotOnlineFailCases:BadAlpha", ...
                "%s id=%d: alphaDesign が不正のためスキップします。", mk, sampleId);
            continue;
        end
        outPath = plotOnlineExampleCase(cfg, cohort, mk, alphaDesign, failDir, sampleId, ...
            struct("fileTag", "fail", "titleNote", char(outcome)));
        outPaths(end + 1, 1) = string(outPath); %#ok<AGROW>
    end
end

end

function alpha = resolveFailCaseAlpha(row)
alpha = nan;
if ismember("alphaDesign", row.Properties.VariableNames) && isfinite(row.alphaDesign(1))
    alpha = row.alphaDesign(1);
elseif ismember("alpha", row.Properties.VariableNames) && isfinite(row.alpha(1)) && row.alpha(1) > 0
    alpha = row.alpha(1);
end
end
