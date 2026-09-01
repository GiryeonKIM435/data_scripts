function yieldInfo = buildCausalYieldInfo(defAdj, forceAdj, filtItem, fitCfg, contactYieldInfo, yieldForceNRel)
%buildCausalYieldInfo percent_yield 因果帯域用 yieldInfo（動的 yieldForceN）

yieldInfo = buildStreamingYieldInfo(defAdj, forceAdj, filtItem, fitCfg, contactYieldInfo);
yieldInfo.yieldForceN = double(yieldForceNRel);
if isstruct(contactYieldInfo) && isfield(contactYieldInfo, "yieldDefMm")
    yieldInfo.yieldDefMm = contactYieldInfo.yieldDefMm;
end

end
