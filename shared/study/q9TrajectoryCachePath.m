function cachePath = q9TrajectoryCachePath(cacheDir, lowKey, highKey)
%q9TrajectoryCachePath Q9 piecewise 軌跡キャッシュファイルパス

if nargin < 3
    error("q9TrajectoryCachePath:NeedKeys", ...
        "lowKey と highKey が必要です。");
end

cachePath = fullfile(cacheDir, sprintf("q9_traj_piecewise_%s__%s.mat", ...
    char(lowKey), char(highKey)));

end
