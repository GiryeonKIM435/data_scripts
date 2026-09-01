function rEq = computeEquivalentRadius(x, y, z)
%computeEquivalentRadius 3方向直径から等価球半径 [mm]
%
% r_eq = (x * y * z / 8)^(1/3) = d_eq / 2
% 解析の主変数は等価直径 d_eq（computeEquivalentDiameter）。本関数は互換用。

rEq = computeEquivalentDiameter(x, y, z) / 2;
end

