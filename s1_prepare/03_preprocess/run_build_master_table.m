function run_build_master_table(opts)
%RUN_BUILD_MASTER_TABLE 推定結果を統合した master テーブルを構築

if nargin < 1 || isempty(opts), opts = defaultRunOptions(); end
yieldPipeline_ensurePaths();
cfg = runOptionsToConfig(opts);
reg = PredictorRegistry();

if shouldSkipCompute(opts, cfg.paths.masterTable, true)
    fprintf("既存: %s\n", cfg.paths.masterTable);
    return;
end

if ~isfile(cfg.paths.tomatoWithFit)
    run_fit_burgers_visco(opts);
end
krMissing = ~isfile(cfg.paths.krTable);
krStale = ~krMissing && isKrArtifactStale(cfg.paths.krTable);
if krMissing
    if isEstimateStageEnabled(opts)
        run_estimate_kr(opts);
    else
        error("build_master_table:MissingKr", ...
            "kr_table.mat がありません。doEstimate=true で run_estimate_kr を実行してください。");
    end
elseif krStale
    if isEstimateStageEnabled(opts)
        fprintf("build_master_table: kr_table が設定と不一致のため再推定します\n");
        run_estimate_kr(opts);
    else
        warning("build_master_table:StaleKr", ...
            "kr_table.mat は設定と不一致ですが doEstimate=false のため既存ファイルを使用します。最新の kr が必要なら doEstimate=true で再実行してください。");
    end
end
if ~isfile(cfg.paths.creepWaveforms)
    run_extract_creep_waveform(opts);
end

sFit = load(cfg.paths.tomatoWithFit, "tomatoDataWithFit", "metadataTomato");
sKr = load(cfg.paths.krTable, "krExport", "metadata");
sWf = load(cfg.paths.creepWaveforms, "waveformMatrix", "waveformIds", "timeGrid", "metadata");

masterTable = buildMasterPredictorTable(sFit.tomatoDataWithFit, sKr.krExport);
waveformMatrix = sWf.waveformMatrix;
waveformIds = sWf.waveformIds(:);
timeGrid = sWf.timeGrid;

[found, loc] = ismember(masterTable.id, waveformIds);
if any(~found)
    warning("build_master_table:MissingWaveform", ...
        "波形のない ID: %s", mat2str(masterTable.id(~found).'));
end
wfAligned = nan(height(masterTable), size(waveformMatrix, 2));
wfAligned(found, :) = waveformMatrix(loc(found), :);

missingCols = reg.paramPredictors(~ismember(reg.paramPredictors, ...
    string(masterTable.Properties.VariableNames)));
if ~isempty(missingCols)
    warning("build_master_table:MissingPredictorColumns", ...
        "master に欠損列があります: %s", strjoin(missingCols, ", "));
end

metadata = struct();
metadata.createdAt = datetime("now");
metadata.predictors = reg.paramPredictors;
metadata.outlierBasePredictors = reg.outlierBasePredictors;
metadata.predictorFingerprint = predictorRegistryFingerprint();
metadata.targetName = reg.targetName;
metadata.krAnalyzeKeys = reg.krAnalyzeKeys;
metadata.krRegistryFingerprint = krMethodRegistryFingerprint();
metadata.krMethodKeys = string({KrMethodRegistry().key});
metadata.waveformNPoints = reg.waveformNPoints;
metadata.waveformIds = masterTable.id;
metadata.nRows = height(masterTable);
if isfield(sFit, "metadataTomato")
    metadata.sourceTomato = sFit.metadataTomato;
end
if isfield(sKr, "metadata")
    metadata.krTableMetadata = sKr.metadata;
end

masterTable = sortrows(masterTable, "id");
waveformMatrix = wfAligned;
save(cfg.paths.masterTable, "masterTable", "waveformMatrix", "timeGrid", "metadata", "-v7");
fprintf("master テーブル: %d 行 -> %s\n", height(masterTable), cfg.paths.masterTable);
end
