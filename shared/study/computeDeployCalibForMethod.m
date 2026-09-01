function calib = computeDeployCalibForMethod(cfg, cohort, methodKey, krVariant)
%computeDeployCalibForMethod 1 方式分の deploy LOO 校正 (a,b)

if nargin < 4 || isempty(krVariant)
    krVariant = cfg.deploy.krVariant;
end

tbl = cohort.predictorTable;
y = cohort.y;
krCol = resolveDeployKrColumn(tbl, methodKey, krVariant);
if ismember(krCol, tbl.Properties.VariableNames)
    krBatch = tbl{:, krCol}(:);
    if nnz(isfinite(krBatch)) < max(3, round(0.5 * cohort.n))
        krBatch = computePaperOfflineKrBatch(cohort, cfg, methodKey, krVariant);
    end
else
    krBatch = computePaperOfflineKrBatch(cohort, cfg, methodKey, krVariant);
end
calib = fitDeployCalibLoocv(krBatch, y);

end
