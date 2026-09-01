function results = run_sensitivity_checks_summary(cfg, opts)
%RUN_SENSITIVITY_CHECKS_SUMMARY Compare single-factor sensitivity arms to primary
%
% Metrics: cohort n, offline min-MAE key/MAE, sequential min Final-update MAE,
% best complementary (additional-predictor) deltaMae vs stiffness-only.

if nargin < 1 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "baselineTag")
    opts.baselineTag = "jeffreys_bi_iqr15";
end
if ~isfield(opts, "armSpecs")
    opts.armSpecs = defaultArmSpecs();
end

outDir = cfg.out.sensitivity;
if ~isfolder(outDir)
    mkdir(outDir);
end
paperDir = cfg.out.paperTables;
if ~isfolder(paperDir)
    mkdir(paperDir);
end

gammaTag = "gamma_" + strrep(sprintf("%.1f", cfg.q7.gammaValues(1)), ".", "p");
defaultKrVariant = string(cfg.deploy.krVariant);
if strlength(defaultKrVariant) == 0
    defaultKrVariant = "chord";
end

armSpecs = opts.armSpecs;
rows = {};
for i = 1:numel(armSpecs)
    spec = armSpecs(i);
    tag = string(spec.tag);
    label = string(spec.label);
    c = resolveArmCfg(cfg, spec);

    armKr = defaultKrVariant;
    if isfield(spec, "krVariant") && strlength(string(spec.krVariant)) > 0
        armKr = string(spec.krVariant);
    end

    cohort = struct("n", nan);
    try
        cohort = loadStudyCohort(c, struct("useOutlierFilter", false));
    catch ME
        warning("run_sensitivity_checks_summary:CohortFail", ...
            "%s: %s", tag, ME.message);
    end

    off = loadOfflineBestLocal(c, tag, armKr);
    on = loadOnlineBestLocal(c, tag, gammaTag);
    contrib = loadContributionBestLocal(c, tag);

    rows(end + 1, :) = { ...
        label, tag, cohort.n, ...
        off.key, off.mae, off.maeSem, off.r2, ...
        on.key, on.mae, on.maeSem, on.r2, on.nFail, ...
        contrib.bestCaseId, contrib.deltaMae, contrib.qValueBH}; %#ok<AGROW>
end

T = cell2table(rows, 'VariableNames', { ...
    'cohortLabel', 'analysisTag', 'n', ...
    'offlineBestKey', 'offlineMae', 'offlineMaeSem', 'offlineR2', ...
    'onlineBestKey', 'onlineFinalUpdateMae', 'onlineMaeSem', 'onlineR2', 'onlineNFail', ...
    'contribBestCaseId', 'contribBestDeltaMae', 'contribBestQbh'});

csvPath = writeTableSafeLocal(T, fullfile(outDir, "sensitivity_vs_primary.csv"));
paperCsv = writeTableSafeLocal(T, fullfile(paperDir, "sensitivity_vs_primary.csv"));

results = struct();
results.createdAt = datetime("now");
results.table = T;
results.csvPath = csvPath;
results.paperCsvPath = paperCsv;
fprintf("Sensitivity vs primary: %s\n", csvPath);
for i = 1:height(T)
    fprintf("  %s (n=%s): offline[%s]=%s N | online[%s]=%s N | contrib[%s] dMAE=%s\n", ...
        T.cohortLabel(i), fmtNum(T.n(i), "%.0f"), ...
        string(T.offlineBestKey(i)), fmtNum(T.offlineMae(i), "%.2f"), ...
        string(T.onlineBestKey(i)), fmtNum(T.onlineFinalUpdateMae(i), "%.2f"), ...
        string(T.contribBestCaseId(i)), fmtNum(T.contribBestDeltaMae(i), "%+.2f"));
end
end

function outPath = writeTableSafeLocal(T, targetPath)
%WRITE TABLE with fallback if target is locked (e.g. open in Excel).
outPath = string(targetPath);
try
    writetable(T, char(outPath));
    return;
catch ME
    isPerm = contains(lower(string(ME.message)), "permission") ...
        || contains(lower(string(ME.identifier)), "permission") ...
        || (isprop(ME, "message") && contains(ME.message, "開けません"));
    if ~isPerm
        rethrow(ME);
    end
end
[folder, name, ext] = fileparts(char(outPath));
stamp = char(datetime("now", "Format", "yyyyMMdd_HHmmss"));
altPath = fullfile(folder, sprintf("%s_%s%s", name, stamp, ext));
writetable(T, altPath);
warning("run_sensitivity_checks_summary:FileLocked", ...
    ["Could not overwrite %s (Permission denied; close Excel/other lock). ", ...
    "Wrote fallback: %s"], char(outPath), altPath);
outPath = string(altPath);
end

function specs = defaultArmSpecs()
specs = struct("tag", {}, "label", {}, "kind", {}, "krVariant", {});
specs(end + 1) = mk("jeffreys_bi_iqr15", "primary_jeffreys_bi_iqr15", "primary", "chord"); %#ok<AGROW>
specs(end + 1) = mk("sens_no_iqr", "sens_IQR_off", "no_iqr", "chord"); %#ok<AGROW>
specs(end + 1) = mk("sens_incl_visual", "sens_visual_excluded_included", "incl_visual", "chord"); %#ok<AGROW>
specs(end + 1) = mk("sens_kr_ls", "sens_kr_LS", "kr_ls", "ls"); %#ok<AGROW>
specs(end + 1) = mk("sens_harvest_0423", "sens_harvest_2026-04-23_only", "harvest_0423", "chord"); %#ok<AGROW>
specs(end + 1) = mk("sens_harvest_0429", "sens_harvest_2026-04-29_only", "harvest_0429", "chord"); %#ok<AGROW>
end

function s = mk(tag, label, kind, krVariant)
if nargin < 4 || isempty(krVariant)
    krVariant = "chord";
end
s = struct("tag", string(tag), "label", string(label), ...
    "kind", string(kind), "krVariant", string(krVariant));
end

function c = resolveArmCfg(cfg, spec)
c = cfg;
kind = string(spec.kind);
switch kind
    case "primary"
        % keep manuscript paths
    case "no_iqr"
        c = applyJeffreysNoIqrPaths(c);
    case "incl_visual"
        c = applyJeffreysInclVisualPaths(c);
    case "kr_ls"
        c = applyJeffreysKrLsPaths(c);
    case "harvest_0423"
        c = applyJeffreysHarvestDayPaths(c, "0423");
    case "harvest_0429"
        c = applyJeffreysHarvestDayPaths(c, "0429");
    otherwise
        error("run_sensitivity_checks_summary:BadKind", "Unknown arm kind: %s", kind);
end
end

function best = loadOfflineBestLocal(cfg, tag, krVariant)
best = struct("key", "", "mae", nan, "maeSem", nan, "r2", nan);
sumPath = fullfile(cfg.out.q1, tag, "offline_best_methods.csv");
if isfile(sumPath)
    B = readtable(sumPath);
    if ismember("methodType", B.Properties.VariableNames)
        row = B(string(B.methodType) == "force_abs", :);
    else
        row = B;
    end
    if ~isempty(row)
        best.key = string(row.krMethodKey(1));
        best.mae = getColFirst(row, ["mae_loocv", "mae"]);
        best.maeSem = getColFirst(row, ["mae_loocv_sem", "maeSem"]);
        best.r2 = getColFirst(row, ["r2_loocv", "r2"]);
        return;
    end
end
S = loadQ1SummaryTable(cfg, tag);
if isempty(S)
    return;
end
if ismember("variant", S.Properties.VariableNames)
    S = S(string(S.variant) == krVariant, :);
end
if ismember("methodType", S.Properties.VariableNames)
    S = S(string(S.methodType) == "force_abs", :);
end
if isempty(S) || ~ismember("mae_loocv", S.Properties.VariableNames)
    return;
end
[~, ix] = min(S.mae_loocv);
best.key = string(S.krMethodKey(ix));
best.mae = S.mae_loocv(ix);
best.maeSem = getColAt(S, ix, "mae_loocv_sem");
best.r2 = getColAt(S, ix, "r2_loocv");
end

function best = loadOnlineBestLocal(cfg, tag, gammaTag)
best = struct("key", "", "mae", nan, "maeSem", nan, "r2", nan, "nFail", nan);
bestPath = fullfile(cfg.out.q7, tag, gammaTag, "q7_design_best_by_scope.csv");
sumPath = fullfile(cfg.out.q7, tag, gammaTag, "q7_design_deploy_summary.csv");
if isfile(bestPath)
    B = readtable(bestPath);
    row = B;
    if ismember("scope", B.Properties.VariableNames)
        row = B(string(B.scope) == "force_abs", :);
    end
    if ~isempty(row)
        best.key = string(row.krMethodKey(1));
        best.mae = getColFirst(row, "finalUpdateMae");
        best.nFail = getColFirst(row, "nSafeStopFail");
    end
end
if isfile(sumPath) && strlength(best.key) > 0
    S = readtable(sumPath);
    sub = S(string(S.krMethodKey) == best.key, :);
    if ~isempty(sub)
        best.maeSem = getColFirst(sub, "finalUpdateMae_sem");
        best.r2 = getColFirst(sub, "finalUpdateR2");
        if ~isfinite(best.nFail)
            best.nFail = getColFirst(sub, "nSafeStopFail");
        end
        if ~isfinite(best.mae)
            best.mae = getColFirst(sub, "finalUpdateMae");
        end
    end
end
end

function out = loadContributionBestLocal(cfg, tag)
out = struct("bestCaseId", "", "deltaMae", nan, "qValueBH", nan);
cand = [ ...
    fullfile(cfg.out.q5, tag, "track_offline_*", "q5_model_comparison_offline.csv"); ...
    fullfile(cfg.out.q5, tag, "q5_model_comparison_offline.csv")];
path = "";
d = dir(cand(1));
if ~isempty(d)
    path = fullfile(d(1).folder, d(1).name);
elseif isfile(cand(2))
    path = cand(2);
end
if strlength(path) == 0 || ~isfile(path)
    return;
end
T = readtable(path);
if ~ismember("deltaMae", T.Properties.VariableNames)
    return;
end
[~, ix] = min(T.deltaMae);  % most negative = largest MAE reduction
if ismember("model", T.Properties.VariableNames)
    out.bestCaseId = string(T.model(ix));
elseif ismember("caseId", T.Properties.VariableNames)
    out.bestCaseId = string(T.caseId(ix));
end
out.deltaMae = T.deltaMae(ix);
if ismember("qValueBH", T.Properties.VariableNames)
    out.qValueBH = T.qValueBH(ix);
end
end

function v = getColFirst(tbl, names)
names = string(names);
v = nan;
for i = 1:numel(names)
    if ismember(names(i), tbl.Properties.VariableNames)
        v = tbl.(names(i))(1);
        return;
    end
end
end

function v = getColAt(tbl, ix, name)
v = nan;
if ismember(name, tbl.Properties.VariableNames)
    v = tbl.(name)(ix);
end
end

function s = fmtNum(v, fmt)
if ~(isfinite(v))
    s = "NA";
else
    s = string(sprintf(fmt, v));
end
end
