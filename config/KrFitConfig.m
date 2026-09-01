function cfg = KrFitConfig()
%KrFitConfig kr 線形フィットのカスケード段階

cfg = struct();
cfg.tiers = [ ...
    struct("name", "strict", "minPoints", 8, "minR2", 0.98); ...
    struct("name", "relaxed", "minPoints", 5, "minR2", 0.95); ...
    struct("name", "best_effort", "minPoints", 3, "minR2", -inf) ...
    ];
cfg.requirePositiveSlope = true;
cfg.clampBandLowToContact = true;
cfg.burgersK1MinPoints = 5;

end
