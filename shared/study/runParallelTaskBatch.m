function results = runParallelTaskBatch(pool, tasks, opts)
%runParallelTaskBatch parfeval で並列実行しクライアント側で進捗を表示
%
% tasks(k).fn    - function_handle
% tasks(k).args  - cell（fn への引数）
% tasks(k).label - 進捗表示用ラベル（任意）
% tasks(k).nOut  - 期待する出力数（既定 1）

if nargin < 3 || isempty(opts)
    opts = struct();
end
n = numel(tasks);
results = cell(n, 1);
if n == 0
    return;
end

prefix = "parallel";
if isfield(opts, "prefix") && strlength(string(opts.prefix)) > 0
    prefix = char(opts.prefix);
end
pollSec = 5;
if isfield(opts, "pollSeconds") && isfinite(opts.pollSeconds)
    pollSec = opts.pollSeconds;
end
if isfield(opts, "tStart")
    tStart = opts.tStart;
else
    tStart = tic;
end

futures = parallel.FevalFuture.empty(n, 0);
nOutEach = zeros(n, 1);
for k = 1:n
    nOut = 1;
    if isfield(tasks(k), "nOut") && isfinite(tasks(k).nOut)
        nOut = tasks(k).nOut;
    end
    nOutEach(k) = nOut;
    futures(k) = parfeval(pool, tasks(k).fn, nOut, tasks(k).args{:});
end

nDone = 0;
while nDone < n
    [idx, result] = fetchNextCompleted(futures, pollSec);
    if isempty(idx)
        probeDone = probeCompletedCount(opts, nDone);
        logStudyProgress(prefix, probeDone, n, "", tStart);
        continue;
    end
    if ~isempty(futures(idx).Error)
        err = futures(idx).Error;
        cancel(futures);
        rethrow(err);
    end
    if nOutEach(idx) > 0
        results{idx} = extractFutureResult(futures(idx), result);
    else
        results{idx} = [];
    end
    nDone = nDone + 1;
    label = "";
    if isfield(tasks(idx), "label") && ~isempty(tasks(idx).label)
        label = char(string(tasks(idx).label));
    end
    logStudyProgress(prefix, nDone, n, label, tStart);
end

end

function [idx, result] = fetchNextCompleted(futures, pollSec)
%fetchNextCompleted 完了 Future の index と結果（あれば）を取得

idx = [];
result = [];
hasZeroOut = arrayfun(@(f) f.NumOutputArguments == 0, futures);
if all(hasZeroOut)
    idx = fetchNext(futures, pollSec);
    return;
end
if ~any(hasZeroOut)
    [idx, result] = fetchNext(futures, pollSec);
    return;
end

tWait = tic;
while toc(tWait) < pollSec
    for k = 1:numel(futures)
        if strcmp(futures(k).State, "finished")
            idx = k;
            if futures(k).NumOutputArguments > 0
                result = extractFutureResult(futures(k), []);
            end
            return;
        end
    end
    pause(0.2);
end

end

function value = extractFutureResult(fut, result)
if nargin >= 2 && ~isempty(result)
    value = result;
    return;
end
outs = fetchOutputs(fut);
if iscell(outs)
    value = outs{1};
else
    value = outs;
end

end

function done = probeCompletedCount(opts, nDone)
done = nDone;
if ~isfield(opts, "completedProbe") || isempty(opts.completedProbe)
    return;
end
probe = opts.completedProbe;
if ~isfield(probe, "fn") || ~isfield(probe, "baseline")
    return;
end
args = {};
if isfield(probe, "args")
    args = probe.args;
end
try
    measured = probe.fn(args{:});
    done = max(nDone, measured - probe.baseline);
catch
end
end
