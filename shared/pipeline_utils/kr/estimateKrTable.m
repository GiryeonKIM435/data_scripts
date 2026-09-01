function [krExport, metadata] = estimateKrTable(tomatoFiltered, tomatoRaw, noiseStats, cfg, reuseFrom)
%ESTIMATEKRTABLE KrMethodRegistry の全方式で kr を推定（wide 出力）
% reuseFrom: 既存 kr_table から列を再利用する場合 struct('krExport', ..., 'metadata', ...)

methods = KrMethodRegistry();
nMethods = numel(methods);

oldExport = [];
oldMeta = [];
if nargin >= 5 && isstruct(reuseFrom)
    if isfield(reuseFrom, "krExport")
        oldExport = reuseFrom.krExport;
    end
    if isfield(reuseFrom, "metadata")
        oldMeta = reuseFrom.metadata;
    end
end
currentContactFp = krContactConfigFingerprint();
currentFitFp = krFitConfigFingerprint();
currentZeroFp = yieldZeroAdjustFingerprint(cfg);

fitCfg = struct();
fitCfg.sigmaNoiseN = noiseStats.sigmaNoiseN;
fitCfg.krContact = KrContactConfig();
fitCfg.krFit = KrFitConfig();
fitCfg.zeroAdjustFirstPoint = getZeroAdjustEnabled(cfg);

rawMap = containers.Map("KeyType", "double", "ValueType", "any");
for i = 1:numel(tomatoRaw)
    rawMap(tomatoRaw(i).id) = tomatoRaw(i);
end

burgersMap = containers.Map("KeyType", "double", "ValueType", "any");
if isfield(cfg, "paths") && isfield(cfg.paths, "tomatoWithFit") && isfile(cfg.paths.tomatoWithFit)
    sFit = load(cfg.paths.tomatoWithFit, "fitResults");
    if isfield(sFit, "fitResults")
        for j = 1:numel(sFit.fitResults)
            burgersMap(sFit.fitResults(j).id) = sFit.fitResults(j);
        end
    end
end

n = numel(tomatoFiltered);
ids = arrayfun(@(x) x.id, tomatoFiltered);
ids = ids(:);
yieldForceN = nan(n, 1);
krValsLs = nan(n, nMethods);
krValsChord = nan(n, nMethods);
success = false(n, nMethods);
fitTier = zeros(n, nMethods);
fitR2 = nan(n, nMethods);
nBand = nan(n, nMethods);

reuseMethod = false(nMethods, 1);
for m = 1:nMethods
    [reuseMethod(m), ~] = canReuseKrMethodFromExport( ...
        methods(m), oldExport, oldMeta, ids, ...
        currentContactFp, currentFitFp, currentZeroFp);
end
nReused = nnz(reuseMethod);
if nReused > 0
    fprintf("kr 列再利用: %d / %d 方式（変更・新規のみ再計算）\n", nReused, nMethods);
end

for m = find(reuseMethod)'
    [krValsLs(:, m), krValsChord(:, m), success(:, m), fitTier(:, m), fitR2(:, m), nBand(:, m)] = ...
        copyKrMethodColumns(methods(m).key, oldExport, ids);
end

for i = 1:n
    id = ids(i);
    yd = tomatoFiltered(i).yieldDropThreshold;
    if isfield(yd, "hasYield") && yd.hasYield
        yieldForceN(i) = yd.force;
    end
    if ~isKey(rawMap, id)
        continue;
    end
    burgersParams = [];
    if isKey(burgersMap, id)
        burgersParams = burgersMap(id);
    end
    try
        [defLoad, forceLoad, ~, yieldInfo, secLoad] = extractLoadingBranchToYield( ...
            rawMap(id).yield, tomatoFiltered(i), fitCfg);
        for m = 1:nMethods
            if reuseMethod(m)
                continue;
            end
            rr = fitKrBand(defLoad, forceLoad, yieldInfo, methods(m), fitCfg, secLoad, burgersParams);
            nBand(i, m) = rr.nBandPoints;
            fitR2(i, m) = rr.r2;
            if rr.success
                krValsLs(i, m) = rr.kr_N_per_mm;
                if isfield(rr, "krChord_N_per_mm")
                    krValsChord(i, m) = rr.krChord_N_per_mm;
                end
                success(i, m) = true;
                fitTier(i, m) = rr.fitTier;
            end
        end
    catch
        % leave nan
    end
end

krExport = table(ids, yieldForceN, 'VariableNames', {'id', 'yieldForceN'});
for m = 1:nMethods
    key = string(methods(m).key);
    krCol = "kr_" + key;
    krLsCol = "krLs_" + key;
    krChordCol = "krChord_" + key;
    krDeltaCol = "krDeltaLsMinusChord_" + key;
    succCol = "krSuccess_" + key;
    tierCol = "krFitTier_" + key;
    r2Col = "krFitR2_" + key;
    nCol = "krNBand_" + key;
    krExport.(krLsCol) = krValsLs(:, m);
    krExport.(krChordCol) = krValsChord(:, m);
    krExport.(krDeltaCol) = krValsLs(:, m) - krValsChord(:, m);
    krExport.(krCol) = krValsLs(:, m);
    krExport.(succCol) = success(:, m);
    krExport.(tierCol) = fitTier(:, m);
    krExport.(r2Col) = fitR2(:, m);
    krExport.(nCol) = nBand(:, m);
    krExport.(krLsCol)(~success(:, m)) = nan;
    krExport.(krChordCol)(~success(:, m)) = nan;
    krExport.(krDeltaCol)(~success(:, m)) = nan;
    krExport.(krCol)(~success(:, m)) = nan;
end

metadata = struct();
metadata.createdAt = datetime("now");
metadata.krMethodKeys = string({methods.key});
metadata.krRegistryFingerprint = krMethodRegistryFingerprint();
metadata.krContactFingerprint = currentContactFp;
metadata.krFitFingerprint = currentFitFp;
metadata.zeroAdjustFingerprint = currentZeroFp;
metadata.krContactMethod = fitCfg.krContact.method;
metadata.nMethods = nMethods;
metadata.nSamples = n;
metadata.nMethodsReused = nReused;
metadata.krMethodFingerprints = buildKrMethodFingerprintStruct(methods);

for m = 1:nMethods
    fprintf("kr 推定 [%s]: 成功 %d / %d\n", methods(m).key, nnz(success(:, m)), n);
end

end
