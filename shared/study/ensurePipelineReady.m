function cfg = ensurePipelineReady()
%ensurePipelineReady s1_prepare 成果物の存在と整合性を確認（再計算はしない）
%
% 不足・不整合時は RUN__paper.m で doLoad / doEstimate / doPreprocess を
% true にして再実行する。

setup_paths();
cfg = PaperStudyConfig();

required = { ...
    cfg.paths.masterTable, ...
    cfg.paths.cohortManifest, ...
    cfg.paths.krTable, ...
    cfg.paths.tomatoDataset, ...
    cfg.paths.tomatoFiltered, ...
    cfg.paths.noiseProfile};

labels = { ...
    "master_analysis_table_bi_iqr15.mat (shipped manuscript cohort)", ...
    "cohort_manifest_bi_iqr15.mat (shipped manuscript cohort)", ...
    "kr_table.mat (doEstimate=true)", ...
    "tomato_dataset.mat (doLoad=true)", ...
    "tomato_filtered.mat (doEstimate=true)", ...
    "noise_profile.mat (doEstimate=true)"};

missing = false(size(required));
for i = 1:numel(required)
    missing(i) = ~isfile(required{i});
end

if any(missing)
    msg = "s1_prepare の成果物が不足しています。" + newline ...
        + "RUN__paper.m で doLoad / doEstimate / doPreprocess を true にして実行してください:" + newline;
    for i = find(missing)
        msg = msg + sprintf("  - %s: %s", labels{i}, required{i}) + newline;
    end
    error("ensurePipelineReady:MissingArtifacts", "%s", msg);
end

staleNotes = strings(0, 1);
if isKrArtifactStale(cfg.paths.krTable)
    staleNotes(end + 1, 1) = "kr_table.mat が KrMethodRegistry / 接触・フィット設定と不一致"; %#ok<AGROW>
end
if isPredictorArtifactStale(cfg.paths.masterTable, "analysis")
    staleNotes(end + 1, 1) = "master_analysis_table.mat が Registry / kr 列と不一致"; %#ok<AGROW>
end
if ~isempty(staleNotes)
    msg = "s1_prepare 成果物が現在の設定と一致しません。" + newline ...
        + "RUN__paper.m で doEstimate=true および doPreprocess=true を実行してください:" + newline;
    for i = 1:numel(staleNotes)
        msg = msg + sprintf("  - %s", staleNotes(i)) + newline;
    end
    msg = msg + sprintf("  - kr_table: %s", cfg.paths.krTable) + newline;
    msg = msg + sprintf("  - master: %s", cfg.paths.masterTable);
    error("ensurePipelineReady:StaleArtifacts", "%s", msg);
end

fprintf("s1_prepare 成果物 OK (master / manifest / kr_table / raw curves)\n");
end
