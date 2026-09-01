function [krCached, lastBandMask, krUpdated, rr] = maybeRefitStreamingKr( ...
    krCached, lastBandMask, bandMask, minBandPoints, fitFn, krVariant)
%maybeRefitStreamingKr 帯域変化時の kr refit（最小点数ゲート + hold-last-good）

if nargin < 6 || isempty(krVariant)
    krVariant = "chord";
end

krUpdated = false;
rr = struct("success", false);

if ~bandMembershipChanged(lastBandMask, bandMask) || ~any(bandMask)
    return;
end

lastBandMask = bandMask;

if sum(bandMask) < minBandPoints
    return;
end

rr = fitFn();
krNew = extractDeployKr(rr, krVariant);
if isfinite(krNew)
    krCached = krNew;
    krUpdated = true;
end

end
