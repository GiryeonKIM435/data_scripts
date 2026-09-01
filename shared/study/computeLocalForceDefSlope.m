function slope = computeLocalForceDefSlope(defLoad, forceLoad, minDefStepMm)
%computeLocalForceDefSlope 力–変形曲線の局所傾き dF/dδ [N/mm]
%
% detectForceRiseOnset.m の computeLocalSlope と同一ロジック。

if nargin < 3 || isempty(minDefStepMm)
    minDefStepMm = KrContactConfig().minDefStepMm;
end

defLoad = defLoad(:);
forceLoad = forceLoad(:);
n = numel(defLoad);
slope = nan(n, 1);
if n < 2
    return;
end

for i = 1:n
    if i == 1
        dDef = defLoad(2) - defLoad(1);
        dForce = forceLoad(2) - forceLoad(1);
    elseif i == n
        dDef = defLoad(n) - defLoad(n - 1);
        dForce = forceLoad(n) - forceLoad(n - 1);
    else
        dDef = defLoad(i + 1) - defLoad(i - 1);
        dForce = forceLoad(i + 1) - forceLoad(i - 1);
    end
    if abs(dDef) >= minDefStepMm
        slope(i) = dForce / dDef;
    end
end

end
