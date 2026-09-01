function [waveformMatrix, waveformIds, timeGrid, metadata] = extractCreepFromFitResults(fitResults, nPoints)
%EXTRACTCREEPFROMFITRESULTS fit 時保存した creep 区間を nPoints にリサンプル

if nargin < 2 || isempty(nPoints)
    nPoints = PredictorRegistry().waveformNPoints;
end

ok = [fitResults.success];
fitOk = fitResults(ok);
ids = [fitOk.id];
n = numel(ids);
waveformMatrix = nan(n, nPoints);
timeGrid = [];

for i = 1:n
    seg = fitOk(i).creepSegment;
    if ~isfield(seg, "tSecRel") || isempty(seg.tSecRel)
        continue;
    end
    tIn = seg.tSecRel(:).';
    xIn = seg.defMm(:).';
    [xr, tOut] = resampleWaveformMatrix(xIn, tIn, nPoints);
    waveformMatrix(i, :) = xr;
    if isempty(timeGrid)
        timeGrid = tOut;
    end
end

validRows = any(isfinite(waveformMatrix), 2);
waveformMatrix = waveformMatrix(validRows, :);
waveformIds = ids(validRows).';
metadata = struct("nPoints", nPoints, "waveformType", "creep", "nValid", sum(validRows));
fprintf("creep 波形: %d / %d 試料を %d 点で保存\n", sum(validRows), n, nPoints);
end
