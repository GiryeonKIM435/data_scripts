function meta = legacyQ4MethodMeta(cfg)
%legacyQ4MethodMeta Q4 従来手法のメタデータ

tLow = cfg.q4.offlineBandStartSec;
tHigh = tLow + cfg.q4.offlineBandWidthSec;
meta = struct();
meta.krMethodKey = char(cfg.q4.methodKey);
meta.methodType = "legacy_time_window";
meta.gridStart = tLow;
meta.gridWidth = cfg.q4.offlineBandWidthSec;
meta.gridValid = true;
meta.label = sprintf("legacy [%.1f, %.1f) s post-contact", tLow, tHigh);
meta.leakCategory = "legacy_fixed_window";
meta.leakNote = sprintf("offline [%.1f,%.1f)s; online trailing %.1fs", ...
    tLow, tHigh, cfg.q4.onlineWindowSec);
meta.offlineBandStartSec = tLow;
meta.offlineBandEndSec = tHigh;
meta.onlineWindowSec = cfg.q4.onlineWindowSec;
meta.krVariant = char(cfg.q4.krVariant);

end
