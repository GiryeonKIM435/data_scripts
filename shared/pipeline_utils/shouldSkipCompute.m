function skip = shouldSkipCompute(opts, outputPath, checkPredictorStale, staleMode)
%SHOULDSKIPCOMPUTE 既存出力をスキップするか判定
% checkPredictorStale=true のとき Registry 変更で再計算

if nargin < 1 || isempty(opts)
    opts = defaultRunOptions();
end
if nargin < 3
    checkPredictorStale = false;
end
if nargin < 4 || isempty(staleMode)
    staleMode = "auto";
end
if opts.forceRecompute
    skip = false;
    return;
end
if ~opts.skipIfExists
    skip = false;
    return;
end
if ~isfile(outputPath)
    skip = false;
    return;
end
if checkPredictorStale && isPredictorArtifactStale(outputPath, staleMode)
    fprintf("Registry 変更検知: 再構築します -> %s\n", outputPath);
    skip = false;
    return;
end
skip = true;
end
