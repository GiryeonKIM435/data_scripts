function out = computeQ6BinnedForceStiffness(def, force, yTrueRel, binWidthN, minBinPoints, minDefStepMm)
%computeQ6BinnedForceStiffness 力ビン内 LS 回帰による stiffness dF/dδ [N/mm]

def = def(:);
force = force(:);

if nargin < 5 || isempty(minBinPoints)
    minBinPoints = 3;
end
if nargin < 6 || isempty(minDefStepMm)
    minDefStepMm = 1e-4;
end

valid = isfinite(def) & isfinite(force) & force >= 0 & force <= yTrueRel;
def = def(valid);
force = force(valid);

if binWidthN <= 0 || ~isfinite(binWidthN) || ~isfinite(yTrueRel) || yTrueRel <= 0
    out = emptyQ6BinnedStiffnessOut(binWidthN);
    return;
end

nBins = floor(yTrueRel / binWidthN) + 1;
binCenterN = zeros(nBins, 1);
stiffness = nan(nBins, 1);
nPoints = zeros(nBins, 1);

for k = 0:(nBins - 1)
    lo = k * binWidthN;
    hi = (k + 1) * binWidthN;
    isLast = (k == nBins - 1);
    if isLast
        inBin = force >= lo & force <= yTrueRel;
    else
        inBin = force >= lo & force < hi;
    end

    defB = def(inBin);
    forceB = force(inBin);
    n = numel(defB);
    nPoints(k + 1) = n;
    binCenterN(k + 1) = (k + 0.5) * binWidthN;

    if n < minBinPoints
        continue;
    end
    if max(defB) - min(defB) < minDefStepMm
        continue;
    end

    p = polyfit(defB, forceB, 1);
    stiffness(k + 1) = p(1);
end

out = struct( ...
    "binWidthN", binWidthN, ...
    "force", binCenterN, ...
    "stiffness", stiffness, ...
    "nPoints", nPoints);

end

function out = emptyQ6BinnedStiffnessOut(binWidthN)
if nargin < 1 || isempty(binWidthN)
    binWidthN = nan;
end
out = struct( ...
    "binWidthN", binWidthN, ...
    "force", zeros(0, 1), ...
    "stiffness", zeros(0, 1), ...
    "nPoints", zeros(0, 1));

end
