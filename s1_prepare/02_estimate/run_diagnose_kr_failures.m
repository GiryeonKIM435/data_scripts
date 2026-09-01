function run_diagnose_kr_failures(opts)
%RUN_DIAGNOSE_KR_FAILURES kr フィット失敗理由の集計 CSV 出力

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);

if ~isfile(cfg.paths.krTable)
    if ~isfile(cfg.paths.tomatoFiltered)
        run_detect_yield_and_filter(opts);
    end
    if ~isfile(cfg.paths.tomatoDataset)
        run_build_tomato_dataset(opts);
    end
    if ~isfile(cfg.paths.noiseProfile)
        run_estimate_noise(opts);
    end
    run_estimate_kr(opts);
end

s = load(cfg.paths.krTable, "krExport", "metadata");
kr = s.krExport;
methods = KrMethodRegistry();
nMethods = numel(methods);
n = height(kr);

rows = cell(0, 8);
for m = 1:nMethods
    key = string(methods(m).key);
    succCol = "krSuccess_" + key;
    tierCol = "krFitTier_" + key;
    r2Col = "krFitR2_" + key;
    nCol = "krNBand_" + key;
    if ~ismember(succCol, kr.Properties.VariableNames)
        continue;
    end
    ok = kr.(succCol);
    nSuccess = nnz(ok);
    nFail = n - nSuccess;
    tierCounts = [0, 0, 0, 0];
    if ismember(tierCol, kr.Properties.VariableNames)
        for ti = 0:3
            tierCounts(ti + 1) = nnz(kr.(tierCol) == ti);
        end
    end
    failMsg = "none";
    if nFail > 0 && ismember(r2Col, kr.Properties.VariableNames)
        failR2 = kr.(r2Col)(~ok);
        failN = kr.(nCol)(~ok);
        lowN = nnz(failN < 3);
        lowR2 = nnz(isfinite(failR2));
        posSlope = nnz(isfinite(failR2) & failR2 >= 0);
        failMsg = sprintf("fail=%d, n<3=%d, hasR2=%d", nFail, lowN, lowR2);
        if lowN == 0 && lowR2 == 0
            failMsg = sprintf("fail=%d, n<3=%d, other=%d", nFail, lowN, nFail);
        elseif lowN == 0 && posSlope == nFail
            failMsg = sprintf("fail=%d, n<3=%d, slope/other=%d", nFail, lowN, nFail);
        end
    end
    rows(end + 1, :) = {char(key), char(methods(m).label), n, nSuccess, ...
        tierCounts(2), tierCounts(3), tierCounts(4), failMsg}; %#ok<AGROW>
end

summaryTable = cell2table(rows, 'VariableNames', ...
    {'methodKey', 'label', 'nSamples', 'nSuccess', 'nTier1', 'nTier2', 'nTier3', 'failNotes'});

outCsv = fullfile(cfg.out.estimate, "kr_fit_diagnostic_summary.csv");
writetable(summaryTable, outCsv);
fprintf("kr 診断サマリー: %s\n", outCsv);
disp(summaryTable);

end
