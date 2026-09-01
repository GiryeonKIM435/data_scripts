function stats = compareQ5CasesStats(offline, online, cfg, outDir)
%compareQ5CasesStats 後方互換ラッパ（runQ5ModelComparison に委譲）

stats = runQ5ModelComparison(offline, online, cfg, outDir);
end
