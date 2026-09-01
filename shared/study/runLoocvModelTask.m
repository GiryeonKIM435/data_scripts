function res = runLoocvModelTask(tbl, y, def)
%runLoocvModelTask 1 モデルの LOOCV（並列 worker）

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
if isfield(def, "collinearityCfg")
    cvResFull = runLoocvForPredictorsWithCollinearity(tbl, y, preds, def.collinearityCfg, loocvOpts);
else
    cvResFull = runLoocvForPredictorsWithCollinearity(tbl, y, preds, makeQ5CollinearityCfg(PaperStudyConfig()), loocvOpts);
end

res = struct();
res.name = string(def.name);
res.predictors = preds;
res.cv = cvResFull.cv;
res.metrics = cvResFull.metrics;
if isfield(cvResFull, "foldSelected")
    res.foldSelected = cvResFull.foldSelected;
end
if isfield(cvResFull, "foldRemovedLog")
    res.foldRemovedLog = cvResFull.foldRemovedLog;
end

end
