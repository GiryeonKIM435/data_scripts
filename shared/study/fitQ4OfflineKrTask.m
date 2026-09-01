function est = fitQ4OfflineKrTask(sampleCtx, tLow, tHigh, fitCfg, krVariant)
%fitQ4OfflineKrTask Q4 offline 用 kr 推定（並列 worker）

est = fitKrLsContactTimeWindow(sampleCtx, tLow, tHigh, fitCfg, krVariant);

end
