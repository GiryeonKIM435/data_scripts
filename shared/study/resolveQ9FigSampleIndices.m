function sampleIdx = resolveQ9FigSampleIndices(cohort, cfg)
%resolveQ9FigSampleIndices Q9 過程図を出力する試料インデックス

n = cohort.n;
ids = cohort.ids(:);
requested = [];

if isfield(cfg, "q9") && isfield(cfg.q9, "figSampleIds")
    requested = cfg.q9.figSampleIds(:);
end
if isempty(requested)
    nFig = 5;
    if isfield(cfg, "q9") && isfield(cfg.q9, "nFigSamples") && isfinite(cfg.q9.nFigSamples)
        nFig = max(1, round(cfg.q9.nFigSamples));
    end
    nFig = min(nFig, n);
    requested = ids(1:nFig);
end

sampleIdx = zeros(0, 1);
for k = 1:numel(requested)
    id = requested(k);
    loc = find(ids == id, 1, "first");
    if isempty(loc)
        warning("resolveQ9FigSampleIndices:MissingId", ...
            "figSampleIds の id=%d はコホートにありません。スキップします。", id);
        continue;
    end
    sampleIdx(end + 1, 1) = loc; %#ok<AGROW>
end

if isempty(sampleIdx)
    error("resolveQ9FigSampleIndices:NoSamples", ...
        "過程図用の有効な試料 ID がありません。");
end

sampleIdx = unique(sampleIdx, "stable");

nTarget = 5;
if isfield(cfg, "q9") && isfield(cfg.q9, "nFigSamples") && isfinite(cfg.q9.nFigSamples)
    nTarget = max(1, round(cfg.q9.nFigSamples));
end
if numel(sampleIdx) < nTarget
    for i = 1:n
        if numel(sampleIdx) >= nTarget
            break;
        end
        if ~any(sampleIdx == i)
            sampleIdx(end + 1, 1) = i; %#ok<AGROW>
        end
    end
end
if numel(sampleIdx) > nTarget
    sampleIdx = sampleIdx(1:nTarget);
end

end
