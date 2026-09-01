function stats = runQ5ModelComparison(offline, online, cfg, outDir)
%runQ5ModelComparison M0 基準の Wilcoxon ΔMAE 比較（offline / online）+ BH

if nargin < 4
    outDir = "";
end
if nargin < 3 || isempty(cfg)
    cfg = PaperStudyConfig();
end

refName = cfg.q5.referenceCaseId;
stats = struct("offline", table(), "online", table());

if isfield(offline, "modelResults") && ~isempty(offline.modelResults)
    cmpResults = convertOfflineModelResults(offline.modelResults);
    stats.offline = compareModelsToReference(cmpResults, refName, cfg, "offline_loocv");
    if strlength(string(outDir)) > 0
        writetable(stats.offline, fullfile(outDir, "q5_model_comparison_offline.csv"));
    end
end

if nargin >= 2 && isstruct(online) && isfield(online, "perSampleTable") ...
        && ~isempty(online.perSampleTable)
    onlineResults = buildOnlineModelResults(online.perSampleTable, offline.modelResults, cfg);
    if ~isempty(onlineResults)
        stats.online = compareModelsToReference(onlineResults, refName, cfg, "online_deploy");
        if strlength(string(outDir)) > 0
            writetable(stats.online, fullfile(outDir, "q5_model_comparison_online.csv"));
        end
    end
end

legacy = buildLegacyCaseDiffTables(stats);
if strlength(string(outDir)) > 0
    if ~isempty(legacy.offline)
        writetable(legacy.offline, fullfile(outDir, "q5_case_diff_offline.csv"));
    end
    if ~isempty(legacy.online)
        writetable(legacy.online, fullfile(outDir, "q5_case_diff_online.csv"));
    end
end
stats.legacy = legacy;

end

function cmpResults = convertOfflineModelResults(modelResults)
cmpResults = repmat(struct("name", "", "predictors", "", "cv", struct(), "metrics", struct()), ...
    numel(modelResults), 1);
for i = 1:numel(modelResults)
    mr = modelResults(i);
    cmpResults(i).name = string(mr.name);
    cmpResults(i).predictors = mr.predictors;
    cmpResults(i).cv = mr.cv;
    cmpResults(i).metrics = mr.metrics;
end
end

function onlineResults = buildOnlineModelResults(perSampleTable, offlineModelResults, cfg)
perSampleAlpha = isfield(cfg, "q5") && isfield(cfg.q5, "perSampleDesignAlpha") ...
    && logical(cfg.q5.perSampleDesignAlpha);
if perSampleAlpha
    sub = perSampleTable(isfinite(perSampleTable.finalUpdateErrorN), :);
else
    alpha = resolveQ5PrimaryAlpha(cfg);
    sub = perSampleTable(abs(perSampleTable.alpha - alpha) < 1e-9 ...
        & isfinite(perSampleTable.finalUpdateErrorN), :);
end
if isempty(sub)
    onlineResults = [];
    return;
end

caseIds = strings(numel(offlineModelResults), 1);
for i = 1:numel(offlineModelResults)
    caseIds(i) = string(offlineModelResults(i).caseId);
end

onlineResults = repmat(struct("name", "", "predictors", "", "cv", struct(), "metrics", struct()), ...
    numel(caseIds), 1);
for ci = 1:numel(caseIds)
    cid = caseIds(ci);
    rows = sub(string(sub.caseId) == cid, :);
    ids = rows.id(:);
    yTrue = rows.yTrue(:);
    stopErr = rows.finalUpdateErrorN(:);
    yPred = rows.y_hat_finalUpdate(:);
    cv = struct("yTrue", yTrue, "yPred", yPred, "ids", ids);
    cv.metrics = calcMetrics(yTrue, yPred);
    onlineResults(ci).name = cid;
    onlineResults(ci).predictors = offlineModelResults(ci).predictors;
    onlineResults(ci).cv = cv;
    onlineResults(ci).metrics = cv.metrics;
end

onlineResults = alignOnlineResultsByIds(onlineResults);
end

function onlineResults = alignOnlineResultsByIds(onlineResults)
if isempty(onlineResults)
    return;
end
commonIds = onlineResults(1).cv.ids(:);
for ci = 2:numel(onlineResults)
    commonIds = intersect(commonIds, onlineResults(ci).cv.ids(:), "stable");
end
if isempty(commonIds)
    return;
end
for ci = 1:numel(onlineResults)
    cv = onlineResults(ci).cv;
    [~, ia] = ismember(commonIds, cv.ids);
    ia = ia(ia > 0);
    if numel(ia) ~= numel(commonIds)
        [~, ia, ~] = intersect(cv.ids, commonIds, "stable");
    end
    [~, ia] = ismember(commonIds, cv.ids);
    mask = ia > 0;
    idsUse = commonIds(mask);
    ia = ia(mask);
    onlineResults(ci).cv.yTrue = cv.yTrue(ia);
    onlineResults(ci).cv.yPred = cv.yPred(ia);
    onlineResults(ci).cv.ids = idsUse;
    onlineResults(ci).cv.metrics = calcMetrics(onlineResults(ci).cv.yTrue, onlineResults(ci).cv.yPred);
    onlineResults(ci).metrics = onlineResults(ci).cv.metrics;
end
end

function alpha = resolveQ5PrimaryAlpha(cfg)
alpha = cfg.deploy.primaryAlpha;
if isfield(cfg, "q5") && isfield(cfg.q5, "primaryAlpha")
    alpha = cfg.q5.primaryAlpha;
end
end

function legacy = buildLegacyCaseDiffTables(stats)
legacy = struct("offline", table(), "online", table());
legacy.offline = bootstrapTableToLegacy(stats.offline);
legacy.online = bootstrapTableToLegacy(stats.online);
end

function out = bootstrapTableToLegacy(tbl)
if isempty(tbl)
    out = table();
    return;
end
nPaired = nan(height(tbl), 1);
out = table(string(tbl.model), tbl.deltaMae, tbl.deltaMae, tbl.cohenDz, ...
    tbl.pWilcoxon, nPaired, string(tbl.referenceModel), tbl.qValueBH, ...
    'VariableNames', {'caseId', 'deltaMaeMean', 'deltaMaeMedian', 'rankBiserial', ...
    'pWilcoxon', 'nPaired', 'referenceCase', 'qValueBH'});
end
