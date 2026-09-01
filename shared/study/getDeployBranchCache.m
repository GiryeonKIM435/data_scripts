function branch = getDeployBranchCache(artifacts, sampleId)
%getDeployBranchCache 試料ごとの loading 枝をキャッシュ付きで取得

sampleId = double(sampleId);
if isKey(artifacts.branchCache, sampleId)
    branch = artifacts.branchCache(sampleId);
    return;
end

if ~isKey(artifacts.rawMap, sampleId) || ~isKey(artifacts.filtMap, sampleId)
    error("getDeployBranchCache:MissingSample", "試料 %d の生データがありません。", sampleId);
end

rawItem = artifacts.rawMap(sampleId);
filtItem = artifacts.filtMap(sampleId);
[defLoad, forceLoad, ~, yieldInfo, secLoad] = extractLoadingBranchToYield( ...
    rawItem.yield, filtItem, artifacts.fitCfg);

branch = struct();
branch.defLoad = defLoad;
branch.forceLoad = forceLoad;
branch.yieldInfo = yieldInfo;
branch.secLoad = secLoad;
branch.yieldForceN = yieldInfo.yieldForceN;
artifacts.branchCache(sampleId) = branch;
end
