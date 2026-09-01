function manifest = run_assemble_paper_outputs(cfg)
%RUN_ASSEMBLE_PAPER_OUTPUTS Collect paper-ready figures/tables
%
% Copies stage products into paper_figures / paper_tables with stable names
% and writes paper_outputs_manifest.csv. Missing sources are recorded.

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end

figDir = cfg.out.paperFigures;
tabDir = cfg.out.paperTables;
for d = {figDir, tabDir}
    if ~isfolder(d{1})
        mkdir(d{1});
    end
end

analysisTag = resolvePaperQ3AnalysisTag(cfg);
gammaTag = "gamma_" + strrep(sprintf("%.1f", cfg.q7.gammaValues(1)), ".", "p");
sec41 = cfg.out.q0;
sec42 = fullfile(cfg.out.q1, analysisTag);
sec43 = fullfile(cfg.out.q7, analysisTag, gammaTag);
sec44 = fullfile(cfg.out.q5, analysisTag);

entries = {};
% --- 4.1 descriptive ---
entries(end + 1, :) = {fullfile(sec41, "table1_sample_descriptives.csv"), ...
    fullfile(tabDir, "table1_sample_descriptives.csv"), "4.1 Table 1"};
entries(end + 1, :) = {fullfile(sec41, "table1_sample_descriptives.tex"), ...
    fullfile(tabDir, "table1_sample_descriptives.tex"), "4.1 Table 1 (TeX)"};
entries(end + 1, :) = {fullfile(sec41, "table1_sample_descriptives_preview.png"), ...
    fullfile(tabDir, "table1_sample_descriptives_preview.png"), "4.1 Table 1 (preview)"};
entries(end + 1, :) = {fullfile(sec41, "table1_deq_note.txt"), ...
    fullfile(tabDir, "table1_deq_note.txt"), "4.1 d_eq footnote"};
entries(end + 1, :) = {fullfile(sec41, "table_kr_chord_range.csv"), ...
    fullfile(tabDir, "table_kr_chord_range.csv"), "4.1 chord stiffness k range"};
entries(end + 1, :) = {fullfile(sec41, "table_harvest_batch_summary.csv"), ...
    fullfile(tabDir, "table_harvest_batch_summary.csv"), "4.1 harvest batch summary"};

% --- 4.2 post-test (paper: heatmap a + best CSV) ---
entries(end + 1, :) = {fullfile(sec42, "fig4_2_offline_mae_r2_force_abs.png"), ...
    fullfile(figDir, "fig_res_heatmap_posttest_mae_r2_force_abs.png"), ...
    "4.2 post-test MAE±SEM/R^2 heatmap (force_abs; fig:res_heatmap a)"};
entries(end + 1, :) = {fullfile(sec42, "offline_best_methods.csv"), ...
    fullfile(tabDir, "posttest_best_methods.csv"), "4.2 best methods (interval / MAE)"};
entries(end + 1, :) = {fullfile(sec42, "table_interval_preyield_feasibility.csv"), ...
    fullfile(tabDir, "table_interval_preyield_feasibility.csv"), ...
    "Methods interval pre-yield feasibility"};
entries(end + 1, :) = {fullfile(sec42, "table_interval_preyield_feasibility_meta.csv"), ...
    fullfile(tabDir, "table_interval_preyield_feasibility_meta.csv"), ...
    "Methods interval pre-yield meta"};

% --- 4.3 sequential replay (paper: heatmap b + example) ---
exampleHits = dir(fullfile(sec43, "fig4_3_online_example_*.png"));
for i = 1:numel(exampleHits)
    entries(end + 1, :) = {fullfile(sec43, exampleHits(i).name), ...
        fullfile(figDir, strrep(exampleHits(i).name, "fig4_3_online_", "fig_res_sequential_")), ...
        "4.3 sequential-replay control example (fig:res_online_example)"}; %#ok<AGROW>
end
entries(end + 1, :) = {fullfile(sec43, "fig4_3_online_finalupdate_mae_bioyield_premature_force_abs.png"), ...
    fullfile(figDir, "fig_res_heatmap_sequential_mae_bioyield_premature_force_abs.png"), ...
    "4.3 sequential MAE+bioyield+premature heatmap (force_abs; fig:res_heatmap b)"};
entries(end + 1, :) = {fullfile(sec43, "table_online_early_stop_by_method.csv"), ...
    fullfile(tabDir, "table_sequential_premature_by_method.csv"), ...
    "4.3 premature protective-stop counts"};
entries(end + 1, :) = {fullfile(sec43, "q7_design_best_by_scope.csv"), ...
    fullfile(tabDir, "sequential_best_by_scope.csv"), "4.3 sequential best conditions"};

% --- 4.4 additional predictors (Spearman + post-test LOOCV scatter) ---
entries(end + 1, :) = {fullfile(sec44, "table4_4_predictor_correlation.csv"), ...
    fullfile(tabDir, "table4_4_predictor_correlation.csv"), "4.4 correlation/VIF table"};
entries(end + 1, :) = {fullfile(sec44, "table4_4_predictor_correlation.tex"), ...
    fullfile(tabDir, "table4_4_predictor_correlation.tex"), "4.4 correlation/VIF table (TeX)"};
entries(end + 1, :) = {fullfile(sec44, "table4_4_predictor_correlation_preview.png"), ...
    fullfile(tabDir, "table4_4_predictor_correlation_preview.png"), "4.4 correlation table (preview)"};
entries(end + 1, :) = {fullfile(sec44, "fig4_4_spearman_corr_matrix.png"), ...
    fullfile(figDir, "fig_res_spearman_corr_matrix.png"), ...
    "4.4 Spearman correlation matrix (fig:res_q5_corr)"};
offlineTracks = dir(fullfile(sec44, "track_offline_*"));
for i = 1:numel(offlineTracks)
    if ~offlineTracks(i).isdir
        continue;
    end
    srcScatter = fullfile(sec44, offlineTracks(i).name, "fig_q5_offline_loocv_scatter.png");
    entries(end + 1, :) = {srcScatter, ...
        fullfile(figDir, "fig_res_q5_offline_loocv_scatter.png"), ...
        "4.4 post-test LOOCV multi-panel scatter (fig:res_q5_scatter)"}; %#ok<AGROW>
    break;
end

% --- Methods audits ---
yieldAuditDir = fullfile(cfg.out.root, "sec4_yield_detection");
entries(end + 1, :) = {fullfile(yieldAuditDir, "fig_yield_detection_examples.png"), ...
    fullfile(figDir, "fig_methods_bioyield_examples.png"), "Methods bioyield detection examples"};
entries(end + 1, :) = {fullfile(yieldAuditDir, "yield_detection_rules.txt"), ...
    fullfile(tabDir, "bioyield_detection_rules.txt"), "Methods bioyield detection rules"};
entries(end + 1, :) = {fullfile(yieldAuditDir, "table_yield_detection_filter_counts.csv"), ...
    fullfile(tabDir, "table_bioyield_detection_filter_counts.csv"), "Methods bioyield filter counts"};
jeffreysAuditDir = fullfile(cfg.out.root, "sec4_jeffreys_fit");
entries(end + 1, :) = {fullfile(jeffreysAuditDir, "fig_jeffreys_fit_examples.png"), ...
    fullfile(figDir, "fig_methods_jeffreys_fit_examples.png"), "Methods Jeffreys fit examples"};
entries(end + 1, :) = {fullfile(jeffreysAuditDir, "jeffreys_fit_rules.txt"), ...
    fullfile(tabDir, "jeffreys_fit_rules.txt"), "Methods Jeffreys fit rules"};
entries(end + 1, :) = {fullfile(jeffreysAuditDir, "table_jeffreys_fit_counts.csv"), ...
    fullfile(tabDir, "table_jeffreys_fit_counts.csv"), "Methods Jeffreys fit counts"};

% Also collect sibling .fig files for MATLAB editing
entries = appendSiblingFigEntries(entries);

nEntries = size(entries, 1);
status = strings(nEntries, 1);
for i = 1:nEntries
    src = char(string(entries{i, 1}));
    dst = char(string(entries{i, 2}));
    if ~isfile(src)
        status(i) = "missing";
        continue;
    end
    if isSameAssemblePath(src, dst)
        status(i) = "already_in_place";
        continue;
    end
    try
        copyfile(src, dst);
        status(i) = "copied";
    catch ME
        if contains(ME.message, "それ自身") || contains(lower(ME.message), "itself")
            status(i) = "already_in_place";
        else
            rethrow(ME);
        end
    end
end

manifest = table(string(entries(:, 3)), string(entries(:, 1)), ...
    string(entries(:, 2)), status, ...
    'VariableNames', {'paperItem', 'source', 'destination', 'status'});
writetable(manifest, fullfile(cfg.out.root, "paper_outputs_manifest.csv"));

nMissing = nnz(status == "missing");
nFig = nnz(endsWith(string(entries(:, 2)), ".fig"));
fprintf("assemble: copied %d/%d (missing=%d, .fig=%d) -> %s / %s\n", ...
    nEntries - nMissing, nEntries, nMissing, nFig, figDir, tabDir);
if nMissing > 0
    miss = manifest(manifest.status == "missing", :);
    for i = 1:height(miss)
        fprintf("  missing: %s (%s)\n", miss.paperItem(i), miss.source(i));
    end
end
end

function entries = appendSiblingFigEntries(entries)
%appendSiblingFigEntries Append .fig siblings for PNG entries
n = size(entries, 1);
extra = {};
for i = 1:n
    src = string(entries{i, 1});
    dst = string(entries{i, 2});
    if ~endsWith(lower(src), ".png")
        continue;
    end
    srcFig = regexprep(src, "(?i)\.png$", ".fig");
    dstFig = regexprep(dst, "(?i)\.png$", ".fig");
    item = string(entries{i, 3}) + " (.fig)";
    extra(end + 1, :) = {char(srcFig), char(dstFig), char(item)}; %#ok<AGROW>
end
if ~isempty(extra)
    entries = [entries; extra];
end
end

function tf = isSameAssemblePath(a, b)
%isSameAssemblePath True if paths refer to the same file (Windows/OneDrive-safe)
a = char(string(a));
b = char(string(b));
if strcmpi(strrep(a, "/", "\"), strrep(b, "/", "\"))
    tf = true;
    return;
end
try
    if exist("samefile", "file") == 2
        tf = samefile(a, b);
        return;
    end
catch
end
try
    ca = char(java.io.File(a).getCanonicalPath());
    cb = char(java.io.File(b).getCanonicalPath());
    tf = strcmpi(ca, cb);
catch
    tf = false;
end
end
