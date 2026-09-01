function [hasPiecewise, pwDef, pwForce, hasSingle, seDef, seForce] = detectYieldPoints(def, force, sigmaNoiseN)
hasPiecewise = false; pwDef = nan; pwForce = nan;
hasSingle = false; seDef = nan; seForce = nan;
if isempty(def) || isempty(force), return; end
def = def(:); force = force(:);
valid = isfinite(def) & isfinite(force);
def = def(valid); force = force(valid);
if numel(def) < 3, return; end
if any(diff(def) < 0)
    [def, ord] = sort(def); force = force(ord);
end
[hasPiecewise, pwDef, pwForce] = detectYieldByDropThreshold(def, force, sigmaNoiseN);
[hasSingle, seDef, seForce] = detectYieldBySingleExceed(def, force, sigmaNoiseN);
end

function [hasYield, yDef, yForce] = detectYieldByDropThreshold(def, force, sigmaNoiseN)
hasYield = false; yDef = nan; yForce = nan;
n = numel(force);
if n < 8, return; end
if any(diff(def) <= 0)
    [def, ia] = unique(def, "stable"); force = force(ia); n = numel(def);
end
if n < 8, return; end
kAhead = 3; confirmRun = 2; forceResolution = 0.01;
lastIdx = n - kAhead;
runCount = 0; startIdx = nan;
for j = 1:lastIdx
    fi = force(j); fk = force(j + kAhead);
    if ~(isfinite(fi) && isfinite(fk)), runCount = 0; startIdx = nan; continue; end
    deltaF = fi - fk;
    deltaThreshold = max([3 * sigmaNoiseN, forceResolution]);
    if deltaF > deltaThreshold && force(min(j + 1, n)) <= fi && fi >= 1
        if runCount == 0, startIdx = j; end
        runCount = runCount + 1;
    else
        runCount = 0; startIdx = nan;
    end
    if runCount >= confirmRun
        hasYield = true; yDef = def(startIdx); yForce = force(startIdx); return;
    end
end
end

function [hasYield, yDef, yForce] = detectYieldBySingleExceed(def, force, sigmaNoiseN)
hasYield = false; yDef = nan; yForce = nan;
n = numel(force);
if n < 4, return; end
if any(diff(def) <= 0)
    [def, ia] = unique(def, "stable"); force = force(ia); n = numel(def);
end
kAhead = 5;
deltaThreshold = 3 * sigmaNoiseN + 0.01;
for j = 1:(n - kAhead)
    fi = force(j); fk = force(j + kAhead);
    if isfinite(fi) && isfinite(fk) && fi >= 1 && (fi - fk) > deltaThreshold
        hasYield = true; yDef = def(j); yForce = fi; return;
    end
end
end
