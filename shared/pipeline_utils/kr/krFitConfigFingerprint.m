function fp = krFitConfigFingerprint()
%krFitConfigFingerprint KrFitConfig の内容指紋

cfg = KrFitConfig();
parts = strings(0, 1);
parts(end + 1) = "clamp=" + string(cfg.clampBandLowToContact);
parts(end + 1) = "slope=" + string(cfg.requirePositiveSlope);
parts(end + 1) = "burgersK1Min=" + string(cfg.burgersK1MinPoints);
for i = 1:numel(cfg.tiers)
    t = cfg.tiers(i);
    parts(end + 1) = t.name + ":n" + string(t.minPoints) + ":r2" + string(t.minR2); %#ok<AGROW>
end
fp = strjoin(parts, "|");

end
