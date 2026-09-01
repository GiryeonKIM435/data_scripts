function bundle = runNestedLoocvModels(tbl, y, modelDefs, cfg)
%runNestedLoocvModels モデル定義配列の LOOCV 実行

if nargin < 4 || isempty(cfg)
    cfg = PaperStudyConfig();
end

nModels = numel(modelDefs);
modelResults = repmat(struct( ...
    "name", "", "predictors", string.empty, "cv", struct(), "metrics", struct()), ...
    nModels, 1);

useParallel = false;
if isfield(cfg, "parallel") && isfield(cfg.parallel, "parallelLoocvModels")
    useParallel = logical(cfg.parallel.parallelLoocvModels);
end
poolInfo = ensurePaperStudyParallelPool(cfg);
useParallel = useParallel && poolInfo.active && nModels > 1;

if useParallel
    pool = gcp("nocreate");
    tasks = repmat(struct("fn", [], "args", {{}}, "label", "", "nOut", 1), nModels, 1);
    for mi = 1:nModels
        tasks(mi).fn = @runLoocvModelTask;
        tasks(mi).args = {tbl, y, modelDefs(mi)};
        tasks(mi).label = char(string(modelDefs(mi).name));
        tasks(mi).nOut = 1;
    end
    taskResults = runParallelTaskBatch(pool, tasks, struct( ...
        "prefix", "Q2 nested CV", ...
        "pollSeconds", 5));
    for mi = 1:nModels
        modelResults(mi) = taskResults{mi};
    end
else
    for mi = 1:nModels
        def = modelDefs(mi);
        preds = string(def.predictors(:));
        missing = preds(~ismember(preds, string(tbl.Properties.VariableNames)));
        if ~isempty(missing)
            error("runNestedLoocvModels:MissingPred", "モデル %s: 列がありません: %s", ...
                def.name, strjoin(missing, ", "));
        end
        loocvOpts = struct();
        if isfield(def, "collinearityMode")
            loocvOpts.collinearityMode = def.collinearityMode;
        end
        if isfield(def, "protectedPredictors")
            loocvOpts.protectedPredictors = def.protectedPredictors;
        end
        colCfg = cfg;
        if isfield(def, "collinearityCfg")
            colCfg = def.collinearityCfg;
        elseif isfield(cfg, "q5")
            colCfg = makeQ5CollinearityCfg(cfg);
        end
        resFull = runLoocvForPredictorsWithCollinearity(tbl, y, preds, colCfg, loocvOpts);
        modelResults(mi).name = string(def.name);
        modelResults(mi).predictors = preds;
        modelResults(mi).cv = resFull.cv;
        modelResults(mi).metrics = resFull.metrics;
        if isfield(resFull, "foldSelected")
            modelResults(mi).foldSelected = resFull.foldSelected;
        end
        if isfield(resFull, "foldRemovedLog")
            modelResults(mi).foldRemovedLog = resFull.foldRemovedLog;
        end
    end
end

bundle = struct();
bundle.modelResults = modelResults;
bundle.cfg = cfg;
end
