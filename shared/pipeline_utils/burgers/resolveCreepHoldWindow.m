function win = resolveCreepHoldWindow(item, opts)
%RESOLVECREEPHOLDWINDOW クリープ保持区間の絶対時刻窓を返す
%
% win.tSec, win.defMm, win.creepStartSec, win.creepEndSec, win.speedMmPerMin

if nargin < 2 || isempty(opts)
    opts = burgersDefaultOpts();
end

[tSec, defMm, defPos] = prepareViscoSeries(item);
dtMed = median(diff(tSec(isfinite(diff(tSec)) & diff(tSec) > 0)), "omitnan");
winN = max(opts.minSmoothPoints, round(opts.smoothWindowSec / max(dtMed, eps)));
if mod(winN, 2) == 0
    winN = winN + 1;
end
defSm = movmean(movmedian(defMm, winN, "omitnan"), winN, "omitnan");
speedMmPerMin = gradient(defSm, tSec / 60);

[recoveryIdx, ~, ~] = detectRecoveryStartIndexLocal(tSec, defPos, opts);
recoveryIdx = min(max(recoveryIdx, 3), numel(tSec));
creepEndSecRaw = tSec(recoveryIdx - 1);
creepStartSec = tSec(recoveryIdx) - opts.creepHoldDurationSec;
if creepStartSec <= tSec(1)
    error("resolveCreepHoldWindow:NoStart", "creep開始時刻を確保できません。");
end
creepEndSec = refineCreepEndLocal(tSec, speedMmPerMin, creepEndSecRaw, opts);

win = struct();
win.tSec = tSec;
win.defMm = defMm;
win.creepStartSec = creepStartSec;
win.creepEndSec = creepEndSec;
win.speedMmPerMin = speedMmPerMin;
end

function [tSec, defMm, defPos] = prepareViscoSeries(item)
tSec = (item.visco.microSec(:) - item.visco.microSec(1)) * 1e-6;
defMm = item.visco.deformation(:);
valid = isfinite(tSec) & isfinite(defMm);
tSec = tSec(valid);
defMm = defMm(valid);
if numel(tSec) < 20
    error("resolveCreepHoldWindow:TooFewPoints", "有効データ点が不足");
end
if any(diff(tSec) <= 0)
    [tSec, ord] = sort(tSec);
    defMm = defMm(ord);
end
def0 = defMm - defMm(1);
if abs(min(def0)) > abs(max(def0))
    defPos = -def0;
else
    defPos = def0;
end
end

function [recoveryIdx, peakIdx, candidateIdx] = detectRecoveryStartIndexLocal(tSec, defPos, opts)
n = numel(defPos);
dt = median(diff(tSec), "omitnan");
if ~(isfinite(dt) && dt > 0)
    dt = max(tSec(end) / max(n - 1, 1), 1e-3);
end
strongWinN = max(11, round(opts.recoveryStrongSmoothSec / dt));
if mod(strongWinN, 2) == 0
    strongWinN = strongWinN + 1;
end
epsRecSm = movmean(movmedian(defPos, strongWinN, "omitnan"), strongWinN, "omitnan");
searchStart = max(2, round(opts.recoverySearchStartRatio * n));
[~, localPeak] = max(epsRecSm(searchStart:n));
peakIdx = min(max(localPeak + searchStart - 1, 2), n - 1);
holdWinN = max(5, round(opts.holdMeanWindowSec / dt));
holdMean = mean(epsRecSm(max(searchStart, peakIdx - holdWinN + 1):peakIdx), "omitnan");
recL = max(peakIdx + 1, round(opts.recoveryRangeRatio(1) * n));
recR = min(n, round(opts.recoveryRangeRatio(2) * n));
if recR <= recL
    recL = max(peakIdx + 1, round(0.70 * n));
    recR = n;
end
recoveryMean = mean(epsRecSm(recL:recR), "omitnan");
dropTotal = holdMean - recoveryMean;
if ~(isfinite(dropTotal) && dropTotal > 0)
    dropTotal = epsRecSm(peakIdx) - recoveryMean;
end
if ~(isfinite(dropTotal) && dropTotal > 0)
    recoveryIdx = peakIdx;
    candidateIdx = peakIdx;
    return;
end
targetLevel = epsRecSm(peakIdx) - opts.effectiveDropAlpha * dropTotal;
crossRel = find(epsRecSm(peakIdx:n) <= targetLevel, 1, "first");
if isempty(crossRel)
    candidateIdx = n;
else
    candidateIdx = crossRel + peakIdx - 1;
end
candidateIdx = min(max(candidateIdx, peakIdx + 1), n);
dropCount = max(3, round(opts.minSignificantDropSec / dt));
sigThreshold = mean(epsRecSm(peakIdx:candidateIdx)) - ...
    opts.significanceSigmaScale * max(std(epsRecSm(peakIdx:candidateIdx), "omitnan"), 1e-6);
recoveryIdx = candidateIdx;
for i = (peakIdx + 1):(candidateIdx - dropCount + 1)
    if all(epsRecSm(i:(i + dropCount - 1)) <= sigThreshold)
        recoveryIdx = i;
        break;
    end
end
recoveryIdx = min(max(recoveryIdx, peakIdx + 1), n);
end

function creepEndSec = refineCreepEndLocal(tSec, speedMmPerMin, creepEndSecOrig, opts)
creepEndSec = creepEndSecOrig;
tL = creepEndSecOrig - opts.refinedCreepEndLookBackSec;
tR = creepEndSecOrig + opts.refinedCreepEndLookAheadSec;
mask = isfinite(tSec) & isfinite(speedMmPerMin) & (tSec >= tL) & (tSec <= tR);
if ~any(mask)
    return;
end
tW = tSec(mask);
vW = speedMmPerMin(mask);
iHit = find(vW <= opts.refinedCreepEndSpeedThrMmPerMin, 1, "first");
if ~isempty(iHit)
    creepEndSec = tW(iHit);
end
end
