function sampleCtx = buildDeploySampleContexts(cfg, artifacts, ids, timeOrder, opts)
%BUILDDEPLOYSAMPLECONTEXTS 試料ごとの deploy コンテキストを構築（逐次 or 並列）

if nargin < 5 || isempty(opts)
    opts = struct();
end
prefix = "beforeQ3 sampleCtx";
if isfield(opts, "progressPrefix") && strlength(string(opts.progressPrefix)) > 0
    prefix = char(opts.progressPrefix);
end

ids = ids(:);
n = numel(ids);
sampleCtx = cell(n, 1);

useParallel = false;
if isfield(cfg, "parallel") && isfield(cfg.parallel, "parallelSampleCtx")
    useParallel = logical(cfg.parallel.parallelSampleCtx);
end
poolInfo = ensurePaperStudyParallelPool(cfg);
useParallel = useParallel && poolInfo.active;

tStart = tic;
if useParallel && n > 1
    pool = gcp("nocreate");
    tasks = repmat(struct("fn", [], "args", {{}}, "label", "", "nOut", 1), n, 1);
    for i = 1:n
        tasks(i).fn = @buildOneDeploySampleContext;
        tasks(i).args = {artifacts, ids(i), timeOrder};
        tasks(i).label = sprintf("id%03d", ids(i));
        tasks(i).nOut = 1;
    end
    results = runParallelTaskBatch(pool, tasks, struct( ...
        "prefix", prefix, ...
        "pollSeconds", 5, ...
        "tStart", tStart));
    for i = 1:n
        sampleCtx{i} = results{i};
    end
else
    logEvery = max(1, min(20, ceil(n / 5)));
    for i = 1:n
        sampleCtx{i} = buildOneDeploySampleContext(artifacts, ids(i), timeOrder);
        if n > logEvery && (i == n || mod(i, logEvery) == 0)
            logStudyProgress(prefix, i, n, "", tStart);
        end
    end
end

end

function ctx = buildOneDeploySampleContext(artifacts, sampleId, timeOrder)
ctx = prepareSampleDeployContext(artifacts, sampleId, timeOrder);
end
