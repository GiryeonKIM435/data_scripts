function poolInfo = ensurePaperStudyParallelPool(cfg)
%ensurePaperStudyParallelPool Parallel Pool を設定どおり起動・維持

poolInfo = struct();
poolInfo.active = false;
poolInfo.nWorkers = 0;
poolInfo.requestedWorkers = 0;
poolInfo.profileMaxWorkers = 0;
poolInfo.poolType = "";
poolInfo.compThreads = maxNumCompThreads;

if nargin < 1 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if ~isfield(cfg, "parallel") || ~cfg.parallel.enabled
    return;
end
if ~license("test", "Distrib_Computing_Toolbox")
    warning("ensurePaperStudyParallelPool:NoPCT", ...
        "Parallel Computing Toolbox がありません。逐次実行します。");
    return;
end

poolType = char(cfg.parallel.poolType);
poolInfo.poolType = poolType;
poolInfo.requestedWorkers = cfg.parallel.nWorkers;
targetN = cfg.parallel.nWorkers;

poolInfo.compThreads = configureCompThreads(cfg, targetN);

existing = gcp("nocreate");
if ~isempty(existing)
    if poolMatchesType(existing, poolType) && existing.NumWorkers == targetN
        poolInfo.active = true;
        poolInfo.nWorkers = existing.NumWorkers;
        poolInfo.profileMaxWorkers = existing.NumWorkers;
        return;
    end
    if poolMatchesType(existing, poolType) && existing.NumWorkers < targetN
        fprintf("Parallel pool: %s %d workers → %d に再作成します\n", ...
            poolType, existing.NumWorkers, targetN);
    end
    delete(existing);
end

if ~isfield(cfg.parallel, "autoStart") || ~cfg.parallel.autoStart
    return;
end

[pool, profileMax] = startParallelPool(poolType, targetN);
poolInfo.active = true;
poolInfo.nWorkers = pool.NumWorkers;
poolInfo.profileMaxWorkers = profileMax;
fprintf("Parallel pool: %s, %d workers", poolType, pool.NumWorkers);
if poolInfo.requestedWorkers > pool.NumWorkers
    fprintf(" (requested %d, capped to %d)", poolInfo.requestedWorkers, pool.NumWorkers);
end
fprintf(", maxNumCompThreads=%d\n", poolInfo.compThreads);

end

function compThreads = configureCompThreads(cfg, targetN)
compThreads = maxNumCompThreads;
useSet = true;
if isfield(cfg.parallel, "setCompThreads")
    useSet = logical(cfg.parallel.setCompThreads);
end
if ~useSet
    return;
end

nCores = double(feature("numcores"));
if strcmpi(char(cfg.parallel.poolType), "threads")
    perWorker = 1;
    if isfield(cfg.parallel, "compThreads") && isfinite(cfg.parallel.compThreads)
        perWorker = max(1, round(cfg.parallel.compThreads));
    end
    maxNumCompThreads(perWorker);
    compThreads = maxNumCompThreads;
else
    targetThreads = min(max(1, round(targetN)), nCores);
    maxNumCompThreads(targetThreads);
    compThreads = maxNumCompThreads;
end

end

function [pool, profileMax] = startParallelPool(poolType, targetN)
if strcmpi(poolType, "threads")
    [pool, profileMax] = startThreadsPool(targetN);
    return;
end

profileMax = targetN;
try
    pool = parpool(poolType, targetN);
    profileMax = pool.NumWorkers;
    return;
catch me
    if ~contains(me.message, "Too many workers")
        rethrow(me);
    end
end

cap = parseProfileWorkerCap(me);
if isempty(cap)
    pool = parpool(poolType);
    profileMax = pool.NumWorkers;
    warning("ensurePaperStudyParallelPool:CappedWorkers", ...
        "要求 %d workers ですが profile ""%s"" の既定上限 %d で起動します。", ...
        targetN, poolType, profileMax);
    return;
end

profileMax = cap;
targetN = min(targetN, cap);
warning("ensurePaperStudyParallelPool:CappedWorkers", ...
    "要求を profile ""%s"" の上限 %d workers に合わせました。", poolType, targetN);
pool = parpool(poolType, targetN);

end

function [pool, profileMax] = startThreadsPool(targetN)
nCores = double(feature("numcores"));
targetN = min(max(1, round(targetN)), nCores);
profileMax = targetN;
try
    pool = parpool("threads", targetN);
    profileMax = pool.NumWorkers;
    return;
catch me
    if ~contains(me.message, "Too many workers")
        rethrow(me);
    end
end

cap = parseProfileWorkerCap(me);
if isempty(cap)
    pool = parpool("threads");
    profileMax = pool.NumWorkers;
    warning("ensurePaperStudyParallelPool:CappedThreads", ...
        "threads 要求 %d workers ですが既定上限 %d で起動します。", targetN, profileMax);
    return;
end

profileMax = cap;
targetN = min(targetN, cap);
warning("ensurePaperStudyParallelPool:CappedThreads", ...
    "threads を profile 上限 %d workers に合わせました。", targetN);
pool = parpool("threads", targetN);
profileMax = pool.NumWorkers;

end

function cap = parseProfileWorkerCap(me)
cap = [];
if ~isfield(me, "message")
    return;
end
tok = regexp(me.message, "maximum of (\d+) workers", "tokens", "once");
if ~isempty(tok)
    cap = str2double(tok{1});
end

end

function ok = poolMatchesType(pool, poolType)
if strcmpi(poolType, "threads")
    ok = isa(pool, "parallel.ThreadPool");
elseif strcmpi(poolType, "local") || strcmpi(poolType, "processes")
    ok = ~isa(pool, "parallel.ThreadPool");
elseif isprop(pool, "Type")
    ok = strcmpi(pool.Type, poolType);
else
    ok = false;
end

end
