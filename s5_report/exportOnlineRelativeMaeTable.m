function results = exportOnlineRelativeMaeTable(cfg, opts)
%exportOnlineRelativeMaeTable Minor 2/4: online relative MAE + bootstrap CI 表
%
% Q7 designSummary から論文用の relative MAE / bootstrap CI を抽出する。

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "analysisTag") || strlength(string(opts.analysisTag)) == 0
    opts.analysisTag = resolveQ7AnalysisTag(cfg, struct());
end

gammaTag = "gamma_" + strrep(sprintf("%.1f", cfg.q7.gammaValues(1)), ".", "p");
sumPath = fullfile(cfg.out.q7, opts.analysisTag, gammaTag, "q7_design_deploy_summary.csv");
bestPath = fullfile(cfg.out.q7, opts.analysisTag, gammaTag, "q7_design_best_by_scope.csv");

if ~isfile(sumPath)
    warning("exportOnlineRelativeMaeTable:NoSummary", "summary がありません: %s", sumPath);
    results = struct("table", table());
    return;
end

S = readtable(sumPath);
S = S(string(S.methodType) == "force_abs", :);
if isempty(S)
    results = struct("table", table());
    return;
end

% best 行を先頭に
bestKey = "";
if isfile(bestPath)
    B = readtable(bestPath);
    row = B(string(B.scope) == "force_abs", :);
    if ~isempty(row)
        bestKey = string(row.krMethodKey(1));
        if ismissing(bestKey) || strlength(bestKey) == 0
            bestKey = "";
        end
    end
end

cols = {'krMethodKey', 'label', 'finalUpdateMae', 'finalUpdateMae_sem', ...
    'relativeFinalUpdateError_mean', 'relativeFinalUpdateError_sem', ...
    'nSafeStopFail', 'safeStopRate'};
have = cols(ismember(cols, S.Properties.VariableNames));
T = S(:, have);

% relative MAE %（mean relative error × 100）
if ismember("relativeFinalUpdateError_mean", T.Properties.VariableNames)
    T.relativeMaePct = 100 * T.relativeFinalUpdateError_mean;
end

% bootstrap CI 列（あれば）
ciCandidates = [ ...
    "finalUpdateMae_ci_lo_b5000", "finalUpdateMae_ci_hi_b5000", ...
    "relativeFinalUpdateError_ci_lo_b5000", "relativeFinalUpdateError_ci_hi_b5000"];
for ci = 1:numel(ciCandidates)
    c = ciCandidates(ci);
    if ismember(c, S.Properties.VariableNames)
        T.(c) = S.(c);
    end
end

T.isBest = false(height(T), 1);
if strlength(bestKey) > 0
    T.isBest = string(T.krMethodKey) == bestKey;
    T = [T(T.isBest, :); T(~T.isBest, :)];
end

outDir = fullfile(cfg.out.q7, opts.analysisTag, gammaTag);
csvPath = fullfile(outDir, "table_online_relative_mae_ci.csv");
writetable(T, csvPath);
writetable(T, fullfile(cfg.out.paperTables, "table_online_relative_mae_ci.csv"));

% best のみの短い表
bestOnly = T(T.isBest, :);
writetable(bestOnly, fullfile(cfg.out.paperTables, "table_online_best_relative_mae_ci.csv"));

results = struct();
results.createdAt = datetime("now");
results.table = T;
results.best = bestOnly;
results.csvPath = csvPath;
fprintf("Online relative MAE/CI: %s (best=%s)\n", csvPath, char(bestKey));
end
