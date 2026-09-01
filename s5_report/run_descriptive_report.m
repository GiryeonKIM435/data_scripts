function results = run_descriptive_report(cfg, opts)
%RUN_DESCRIPTIVE_REPORT 結果4.1: 試料特性の記述統計
%
% Measured values (F_yield, L1, L2, h, weight), d_eq, and Jeffreys params (cM, cK, kK).
% 表に出力する。d_eq の定義式は注記（table1_deq_note.txt）と Methods を参照。

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
end
if ~isfield(opts, "writeFigures")
    opts.writeFigures = true;
end
if isfield(cfg, "figures")
    cfg.figures.enabled = logical(opts.writeFigures);
end

outDir = cfg.out.q0;
if ~isfolder(outDir)
    mkdir(outDir);
end

cohort = loadStudyCohort(cfg, struct("useOutlierFilter", opts.useOutlierFilter));
fprintf("4.1 descriptive: cohort n=%d\n", cohort.n);

bundle = buildTable1SampleDescriptives(cohort, cfg, outDir);

% chord stiffness k range (absolute-force intervals)
cfgKr = cfg;
if ~isfield(cfgKr, "deploy") || ~isfield(cfgKr.deploy, "krVariant") ...
        || strlength(string(cfgKr.deploy.krVariant)) == 0
    cfgKr.deploy.krVariant = "chord";
end
krRange = computeKrChordRangeTable(cfgKr, cohort);
krRangePath = fullfile(outDir, "table_kr_chord_range.csv");
writetable(krRange, krRangePath);
fprintf("4.1 descriptive: chord k range -> %s\n", krRangePath);
for ri = 1:height(krRange)
    fprintf("  [%s] nMethods=%d nValues=%d  k = %.3f -- %.3f N/mm\n", ...
        krRange.scope(ri), krRange.nMethods(ri), krRange.nValues(ri), ...
        krRange.k_min(ri), krRange.k_max(ri));
end

% d_eq 注記（表の脚注 / 本文用）
deq = resolveDeqColumn(cohort.predictorTable);
deq = deq(isfinite(deq));
noteLines = [ ...
    sprintf("d_eq = (L1 * L2 * h)^(1/3): mean = %.1f mm, SD = %.1f mm, min = %.1f mm, max = %.1f mm (n = %d)", ...
    mean(deq), std(deq, 0), min(deq), max(deq), numel(deq));
    "d_eq is a derived equivalent diameter from L1, L2, and h (see Methods)."; ...
    "Summary statistics for d_eq are also included in Table 1."];
notePath = fullfile(outDir, "table1_deq_note.txt");
fid = fopen(notePath, "w", "n", "UTF-8");
fprintf(fid, "%s\n", noteLines);
fclose(fid);

results = struct();
results.createdAt = datetime("now");
results.cohort = cohort;
results.table1 = bundle;
results.krChordRange = krRange;
results.krRangePath = krRangePath;
results.deqMean = mean(deq);
results.deqSd = std(deq, 0);
results.notePath = notePath;
results.outputDir = outDir;

fprintf("4.1 descriptive finished: %s (d_eq = %.1f +/- %.1f mm)\n", ...
    outDir, results.deqMean, results.deqSd);
end

function deq = resolveDeqColumn(predTbl)
if ismember("d_eq", string(predTbl.Properties.VariableNames))
    deq = predTbl.d_eq(:);
elseif ismember("r_eq", string(predTbl.Properties.VariableNames))
    deq = 2 * predTbl.r_eq(:);
else
    deq = nan(0, 1);
end
end
