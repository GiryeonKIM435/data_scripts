function r = fitKrBand(defC, forceC, yieldInfo, methodDef, fitCfg, secC, burgersParams)
%FITKRBAND 方式 type に応じて線形 kr を推定

if nargin < 6
    secC = [];
end
if nargin < 7
    burgersParams = [];
end

if isfield(methodDef, "gridValid") && ~methodDef.gridValid
    r = struct( ...
        "success", false, ...
        "kr_N_per_mm", nan, ...
        "krChord_N_per_mm", nan, ...
        "message", "invalid_grid_cell", ...
        "fitTier", 0, ...
        "fitTierName", "", ...
        "nBandPoints", 0, ...
        "r2", nan, ...
        "fLowN", nan, ...
        "fHighN", nan, ...
        "fLowEffN", nan);
    return;
end

if ismember(methodDef.type, ["percent_def"])
    r = fitKrDeformationBand(defC, forceC, yieldInfo, methodDef, fitCfg);
elseif methodDef.type == "time_abs"
    if nargin < 6 || isempty(secC)
        secC = nan(size(defC));
    end
    r = fitKrTimeBandCascade(defC, forceC, secC, yieldInfo, methodDef, fitCfg);
elseif methodDef.type == "time_trailing"
    if nargin < 6 || isempty(secC)
        secC = nan(size(defC));
    end
    r = fitKrTrailingTimeBandCascade(defC, forceC, secC, yieldInfo, methodDef, fitCfg);
elseif methodDef.type == "force_trailing"
    r = fitKrTrailingForceBandCascade(defC, forceC, yieldInfo, methodDef, fitCfg);
else
    r = fitKrLinearBandCascade(defC, forceC, yieldInfo, methodDef, fitCfg);
end

end
