function krBatch = computePaperOfflineKrBatch(cohort, cfg, methodKey, krVariant)
%computePaperOfflineKrBatch offline kr バッチ（master 列 or 生曲線再推定）

tbl = cohort.predictorTable;
krCol = resolveDeployKrColumn(tbl, methodKey, krVariant);
if ismember(krCol, tbl.Properties.VariableNames)
    krBatch = tbl{:, krCol}(:);
    if nnz(isfinite(krBatch)) >= max(3, round(0.5 * cohort.n))
        return;
    end
end

methods = KrMethodRegistry();
mdef = lookupKrMethodRegistry(methodKey, methods);

[sampleCtx, fitCfg, ~] = loadQ4DeploySampleCtx(cfg, cohort);
n = cohort.n;
krBatch = nan(n, 1);
for i = 1:n
    ctx = sampleCtx{i};
    yi = [];
    if isfield(ctx, "yieldInfo")
        yi = ctx.yieldInfo;
    end
    rr = fitKrBand(ctx.def(:), ctx.force(:), yi, mdef, fitCfg, [], []);
    krBatch(i) = extractDeployKr(rr, krVariant);
end

end
