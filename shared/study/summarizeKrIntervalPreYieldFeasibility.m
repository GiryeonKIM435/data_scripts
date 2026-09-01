function T = summarizeKrIntervalPreYieldFeasibility(cfg, cohort)
%summarizeKrIntervalPreYieldFeasibility Major 8: 候補区間が降伏前に完結するか
%
% 各 force_abs 区間 [ξ, ξ+W) について、F_U = ξ+W が各果実の F_yield 未満かを判定。
% F_U < min(F_yield) なら全果実で pre-yield 完結が保証される。

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(cohort)
    cohort = loadStudyCohort(cfg, struct("useOutlierFilter", true));
end

y = double(cohort.y(:));
minY = min(y);
n = numel(y);
methodKeys = listForceAbsMethodKeys(cfg);
methods = KrMethodRegistry();

krMethodKey = strings(numel(methodKeys), 1);
label = strings(numel(methodKeys), 1);
xi = nan(numel(methodKeys), 1);
W = nan(numel(methodKeys), 1);
FU = nan(numel(methodKeys), 1);
nCompletePreYield = nan(numel(methodKeys), 1);
fracComplete = nan(numel(methodKeys), 1);
FU_lt_minY = false(numel(methodKeys), 1);
isPrimarySafe = false(numel(methodKeys), 1);

for mi = 1:numel(methodKeys)
    m = lookupKrMethodRegistry(methodKeys(mi), methods);
    krMethodKey(mi) = methodKeys(mi);
    label(mi) = string(m.label);
    xi(mi) = m.gridStart;
    W(mi) = m.gridWidth;
    FU(mi) = m.gridStart + m.gridWidth;
    ok = y > FU(mi);  % 厳密な半開 [xi, FU) が yield 前に完結
    nCompletePreYield(mi) = sum(ok);
    fracComplete(mi) = nCompletePreYield(mi) / n;
    FU_lt_minY(mi) = FU(mi) < minY;
    % 主比較で安全とされる条件（論文の [0,30) / [5,35)）
    isPrimarySafe(mi) = FU_lt_minY(mi);
end

T = table(krMethodKey, label, xi, W, FU, nCompletePreYield, fracComplete, ...
    FU_lt_minY, isPrimarySafe, ...
    'VariableNames', {'krMethodKey', 'label', 'xi', 'W', 'FU', ...
    'nCompletePreYield', 'fracComplete', 'FU_lt_minYield', 'allFruitsPreYieldGuaranteed'});

meta = table(n, minY, max(y), mean(y), ...
    'VariableNames', {'nCohort', 'minFyield', 'maxFyield', 'meanFyield'});

outDir = fullfile(cfg.out.q1, resolvePaperQ3AnalysisTag(cfg));
if ~isfolder(outDir)
    mkdir(outDir);
end
csvPath = fullfile(outDir, "table_interval_preyield_feasibility.csv");
writetable(T, csvPath);
writetable(meta, fullfile(outDir, "table_interval_preyield_feasibility_meta.csv"));
if isfield(cfg, "out") && isfield(cfg.out, "paperTables")
    writetable(T, fullfile(cfg.out.paperTables, "table_interval_preyield_feasibility.csv"));
    writetable(meta, fullfile(cfg.out.paperTables, "table_interval_preyield_feasibility_meta.csv"));
end

nUnsafe = sum(~T.allFruitsPreYieldGuaranteed);
fprintf("Pre-yield feasibility: min F_yield=%.2f N, intervals with FU>=minY: %d / %d\n", ...
    minY, nUnsafe, height(T));
fprintf("  -> %s\n", csvPath);
end
