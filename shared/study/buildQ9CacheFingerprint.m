function fp = buildQ9CacheFingerprint(cfg, cohort, switchForceN, lowKey, highKey)
%buildQ9CacheFingerprint Q9 piecewise 軌跡キャッシュの指紋

parts = strings(0, 1);
parts(end + 1, 1) = "kind=q9_traj_piecewise";
parts(end + 1, 1) = "switchForceN=" + string(switchForceN);
parts(end + 1, 1) = "lowKey=" + string(lowKey);
parts(end + 1, 1) = "highKey=" + string(highKey);
parts(end + 1, 1) = "ids=" + join(string(cohort.ids(:)'), ",");
parts(end + 1, 1) = "oof=" + string(logical(cohort.useOutlierFilter));
parts(end + 1, 1) = "timeOrder=" + string(cfg.deploy.timeOrder);

krVariant = cfg.deploy.krVariant;
if isfield(cfg, "q9") && isfield(cfg.q9, "krVariant") && strlength(string(cfg.q9.krVariant)) > 0
    krVariant = cfg.q9.krVariant;
end
parts(end + 1, 1) = "krVariant=" + string(krVariant);
parts(end + 1, 1) = "streamRefit=pct_everyStep_gtN";
if isfield(cfg, "deploy") && isfield(cfg.deploy, "minBandPointsForKr")
    parts(end + 1, 1) = "minBandPointsForKr=" + string(cfg.deploy.minBandPointsForKr);
end
if isfield(cfg, "deploy") && isfield(cfg.deploy, "percentYieldBandGatePoints")
    parts(end + 1, 1) = "percentYieldBandGatePoints=" + string(cfg.deploy.percentYieldBandGatePoints);
end

fp = struct();
fp.key = char(join(parts, "|"));
fp.hash = simpleFingerprintHash(fp.key);
fp.createdAt = datetime("now");
fp.kind = "q9_traj_piecewise";

end

function h = simpleFingerprintHash(key)
key = char(string(key));
bytes = uint8(key);
acc = uint64(0);
for i = 1:numel(bytes)
    acc = acc + uint64(bytes(i)) * uint64(131);
    acc = bitand(acc, uint64(4294967295));
end
h = sprintf("%08x", acc);

end
