function artifacts = loadDeployRawArtifacts(cfg)
%loadDeployRawArtifacts Q3 デプロイシミュレーション用の生曲線アーティファクト

sRaw = load(cfg.paths.tomatoDataset, "tomatoData");
sFilt = load(cfg.paths.tomatoFiltered, "tomatoFiltered");
sNoise = load(cfg.paths.noiseProfile, "noiseStats");

pipelineCfg = PipelineConfig();
fitCfg = struct();
fitCfg.sigmaNoiseN = sNoise.noiseStats.sigmaNoiseN;
fitCfg.krContact = KrContactConfig();
fitCfg.krFit = KrFitConfig();
fitCfg.zeroAdjustFirstPoint = getZeroAdjustEnabled(pipelineCfg);

rawMap = containers.Map("KeyType", "double", "ValueType", "any");
for i = 1:numel(sRaw.tomatoData)
    rawMap(sRaw.tomatoData(i).id) = sRaw.tomatoData(i);
end

filtMap = containers.Map("KeyType", "double", "ValueType", "any");
for i = 1:numel(sFilt.tomatoFiltered)
    filtMap(sFilt.tomatoFiltered(i).id) = sFilt.tomatoFiltered(i);
end

artifacts = struct();
artifacts.rawMap = rawMap;
artifacts.filtMap = filtMap;
artifacts.fitCfg = fitCfg;
artifacts.branchCache = containers.Map("KeyType", "double", "ValueType", "any");
artifacts.timeSeriesCache = containers.Map("KeyType", "double", "ValueType", "any");
end
