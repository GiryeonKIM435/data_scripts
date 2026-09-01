function r = fitKrLinearBand(defC, forceC, yieldInfo, methodDef, fitCfg, secC, burgersParams)
%FITKRLINEARBAND 後方互換ラッパ（fitKrBand へ委譲）

if nargin < 6, secC = []; end
if nargin < 7, burgersParams = []; end
r = fitKrBand(defC, forceC, yieldInfo, methodDef, fitCfg, secC, burgersParams);

end
