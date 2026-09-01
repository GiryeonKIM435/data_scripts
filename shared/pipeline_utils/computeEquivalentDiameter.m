function dEq = computeEquivalentDiameter(x, y, z)
%computeEquivalentDiameter 3方向直径から等価球直径 [mm]
%
% d_eq = (x * y * z)^(1/3) = 2 * r_eq
% x, y, z は直径 [mm]。楕円体近似の体積から導かれる等価直径。

x = double(x);
y = double(y);
z = double(z);
dEq = nan(size(x));
mask = isfinite(x) & isfinite(y) & isfinite(z) & (x > 0) & (y > 0) & (z > 0);
if any(mask(:))
    dEq(mask) = (x(mask) .* y(mask) .* z(mask)) .^ (1/3);
end
end
