function results = run_harvest_batch_summary(cfg, opts)
%RUN_HARVEST_BATCH_SUMMARY Minor 5: 収穫日バッチ別の記述統計
%
% 2026-04-23 / 2026-04-29 の2バッチについて、analysis set 内の
% n・F_yield・代表 stiffness の分布比較を出力する。

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = true;
end
if ~isfield(opts, "krMethodKey")
    opts.krMethodKey = "force_s00_w30";  % offline best 既定
end

outDir = fullfile(cfg.out.q0);
if ~isfolder(outDir)
    mkdir(outDir);
end

cohort = loadStudyCohort(cfg, struct("useOutlierFilter", opts.useOutlierFilter));
ids = cohort.ids(:);
y = cohort.y(:);

% 収穫日割当: visco 生データ日付に合わせ id 1–50 → 4/23、それ以外 → 4/29
% （PaperStudyConfig.harvestBatchAMaxId で上書き可）
maxIdBatchA = 50;
if isfield(cfg, "paper") && isfield(cfg.paper, "harvestBatchAMaxId") ...
        && isfinite(cfg.paper.harvestBatchAMaxId)
    maxIdBatchA = cfg.paper.harvestBatchAMaxId;
end
batch = strings(numel(ids), 1);
batch(ids <= maxIdBatchA) = "2026-04-23";
batch(ids > maxIdBatchA) = "2026-04-29";

krVariant = "chord";
if isfield(cfg, "deploy") && isfield(cfg.deploy, "krVariant")
    krVariant = string(cfg.deploy.krVariant);
end
krCol = resolveDeployKrColumn(cohort.predictorTable, opts.krMethodKey, krVariant);
k = nan(numel(ids), 1);
if ismember(krCol, cohort.predictorTable.Properties.VariableNames)
    k = cohort.predictorTable.(krCol);
end

batchLabels = unique(batch, "stable");
rows = {};
for bi = 1:numel(batchLabels)
    m = batch == batchLabels(bi);
    yb = y(m);
    kb = k(m);
    kb = kb(isfinite(kb));
    rows(end + 1, :) = { ...
        batchLabels(bi), sum(m), ...
        mean(yb, "omitnan"), std(yb, 0, "omitnan"), ...
        min(yb), max(yb), ...
        mean(kb, "omitnan"), std(kb, 0, "omitnan"), ...
        min(kb, [], "omitnan"), max(kb, [], "omitnan")}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', { ...
    'harvestDate', 'n', ...
    'Fyield_mean', 'Fyield_sd', 'Fyield_min', 'Fyield_max', ...
    'k_mean', 'k_sd', 'k_min', 'k_max'});

% 探索的: Mann–Whitney (ranksum) for F_yield and k
pY = nan; pK = nan;
m1 = batch == batchLabels(1);
m2 = batch == batchLabels(2);
if any(m1) && any(m2)
    try
        pY = ranksum(y(m1), y(m2));
    catch
        pY = nan;
    end
    k1 = k(m1); k1 = k1(isfinite(k1));
    k2 = k(m2); k2 = k2(isfinite(k2));
    if numel(k1) >= 2 && numel(k2) >= 2
        try
            pK = ranksum(k1, k2);
        catch
            pK = nan;
        end
    end
end

notePath = fullfile(outDir, "table_harvest_batch_note.txt");
fid = fopen(notePath, "w", "n", "UTF-8");
fprintf(fid, "Harvest batch assignment: id<=%d -> 2026-04-23, else -> 2026-04-29\n", maxIdBatchA);
fprintf(fid, "krMethodKey for k: %s (%s)\n", opts.krMethodKey, krCol);
fprintf(fid, "Mann-Whitney p(F_yield)=%.4g, p(k)=%.4g (exploratory)\n", pY, pK);
fclose(fid);

csvPath = fullfile(outDir, "table_harvest_batch_summary.csv");
writetable(T, csvPath);
writetable(T, fullfile(cfg.out.paperTables, "table_harvest_batch_summary.csv"));

results = struct();
results.createdAt = datetime("now");
results.table = T;
results.pFyield = pY;
results.pK = pK;
results.csvPath = csvPath;
results.krMethodKey = string(opts.krMethodKey);
fprintf("Harvest batch summary: %s (p_Fy=%.3g, p_k=%.3g)\n", csvPath, pY, pK);
for i = 1:height(T)
    fprintf("  %s: n=%d, F_yield=%.1f±%.1f N, k=%.2f±%.2f\n", ...
        T.harvestDate(i), T.n(i), T.Fyield_mean(i), T.Fyield_sd(i), ...
        T.k_mean(i), T.k_sd(i));
end
end
