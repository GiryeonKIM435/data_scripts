function ctx = prepareSampleDeployContext(artifacts, sampleId, timeOrder)
%prepareSampleDeployContext 試料の接触零点 loading 枝を 1 回だけ準備
%
% パイプライン kr 推定と同じ extractLoadingBranchToYield（接触検出 + 接触零点）を使用。

if nargin < 3 || isempty(timeOrder)
    timeOrder = "sec_asc";
end

branch = getDeployBranchCache(artifacts, sampleId);
branch = orderDeployBranchSeries(branch, timeOrder);

yi = branch.yieldInfo;
forceOffsetN = 0;
if isfield(yi, "contactForceBeforeZero") && isfinite(yi.contactForceBeforeZero)
    forceOffsetN = yi.contactForceBeforeZero;
end

yTrueRel = branch.yieldForceN;
if ~isfinite(yTrueRel) && isfield(yi, "yieldForceN")
    yTrueRel = yi.yieldForceN;
end
yTrueAbs = yTrueRel + forceOffsetN;

ctx = struct();
ctx.def = branch.defLoad(:);
ctx.force = branch.forceLoad(:);
ctx.sec = branch.secLoad(:);
ctx.n = numel(ctx.def);
ctx.sampleId = sampleId;
ctx.yieldInfo = yi;
ctx.forceOffsetN = forceOffsetN;
ctx.yTrueRel = yTrueRel;
ctx.yTrueAbs = yTrueAbs;
ctx.branchMode = "extractLoadingBranchToYield";

if isKey(artifacts.filtMap, sampleId)
    ctx.filtItem = artifacts.filtMap(sampleId);
else
    ctx.filtItem = [];
end

end
