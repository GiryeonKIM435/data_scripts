function [Xr, tOut] = resampleWaveformMatrix(X, tIn, nPoints)
%RESAMPLEWAVEFORMMATRIX 波形行列を目標点数へ線形補間

if nargin < 3 || isempty(nPoints)
    Xr = X;
    if nargin < 2 || isempty(tIn)
        tOut = linspace(0, 1, size(X, 2));
    else
        tOut = tIn(:).';
    end
    return;
end

nPoints = round(nPoints);
L = size(X, 2);
if nPoints == L
    Xr = X;
    if nargin < 2 || isempty(tIn)
        tOut = linspace(0, 1, L);
    else
        tOut = tIn(:).';
    end
    return;
end

if nPoints < 2
    error("resampleWaveformMatrix:nPoints", "nPoints は 2 以上にしてください。");
end

if nargin < 2 || isempty(tIn) || numel(tIn) ~= L
    tIn = linspace(0, 1, L);
else
    tIn = tIn(:).';
end

tOut = linspace(tIn(1), tIn(end), nPoints);
n = size(X, 1);
Xr = nan(n, nPoints);
for i = 1:n
    row = X(i, :);
    if any(isfinite(row))
        Xr(i, :) = interp1(tIn, row, tOut, "linear", "extrap");
    end
end
end
