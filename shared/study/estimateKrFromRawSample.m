function r = estimateKrFromRawSample(branch, methodDef, fitCfg)
%estimateKrFromRawSample 1 試料の生曲線から kr をリアルタイム推定

rr = fitKrBand(branch.defLoad, branch.forceLoad, branch.yieldInfo, ...
    methodDef, fitCfg, branch.secLoad, []);

r = struct();
r.success = logical(rr.success);
r.krLs = rr.kr_N_per_mm;
if isfield(rr, "krChord_N_per_mm")
    r.krChord = rr.krChord_N_per_mm;
else
    r.krChord = nan;
end
r.nBand = rr.nBandPoints;
r.r2 = rr.r2;
r.fitTier = rr.fitTier;
r.message = "";
if isfield(rr, "message")
    r.message = string(rr.message);
end

if methodDef.type == "force_abs"
    r.bandEndForceN = methodDef.lowN + methodDef.gridWidth;
elseif methodDef.type == "time_abs"
    r.bandEndSec = methodDef.lowSec + methodDef.gridWidth;
    r.bandEndForceN = nan;
elseif methodDef.type == "time_trailing"
    r.bandEndSec = methodDef.offsetSec;
    r.bandEndForceN = nan;
elseif methodDef.type == "force_trailing"
    r.bandEndForceN = methodDef.offsetN + methodDef.gridWidth;
    r.bandEndSec = nan;
elseif methodDef.type == "percent_yield"
    r.bandEndForceN = (methodDef.lowFrac + methodDef.gridWidth / 100) * branch.yieldForceN;
else
    r.bandEndForceN = nan;
    r.bandEndSec = nan;
end
if isfinite(r.bandEndForceN) && isfinite(branch.yieldForceN) && branch.yieldForceN > 0
    r.bandEndOverYield = r.bandEndForceN / branch.yieldForceN;
else
    r.bandEndOverYield = nan;
end

end
