function ok = isDeployCalibChordCompatible(deployCalibChord, nSamples)
%isDeployCalibChordCompatible deploy calib (a,b) がコホート試料数と一致するか

ok = true;
if nargin < 2 || ~isfinite(nSamples) || nSamples < 1
    return;
end
if isempty(deployCalibChord)
    return;
end

for i = 1:numel(deployCalibChord)
    if ~isDeployCalibEntryCompatible(deployCalibChord{i}, nSamples)
        ok = false;
        return;
    end
end

end

function ok = isDeployCalibEntryCompatible(calib, nSamples)
ok = true;
if nargin < 2 || ~isfinite(nSamples) || nSamples < 1
    return;
end
if isempty(calib)
    return;
end
if ~isstruct(calib) || ~isfield(calib, "a") || ~isfield(calib, "b")
    ok = false;
    return;
end
ok = numel(calib.a(:)) == nSamples && numel(calib.b(:)) == nSamples;
end
