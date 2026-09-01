function paths = exportPaperTableBundle(tbl, basePath, caption, cfg)
%exportPaperTableBundle CSV + TeX + 表プレビュー図（PNG/fig）

if nargin < 3 || isempty(caption)
    caption = "Results";
end
if nargin < 4 || isempty(cfg)
    cfg = PaperStudyConfig();
end

exportPaperTables(tbl, basePath, caption);

paths = struct();
paths.csv = char(basePath + ".csv");
paths.tex = char(basePath + ".tex");
paths.preview = "";

writePreview = true;
if isfield(cfg, "figures") && isfield(cfg.figures, "enabled")
    writePreview = logical(cfg.figures.enabled);
end
if writePreview
    previewPath = char(basePath + "_preview.png");
    exportPaperTablePreviewFigure(tbl, previewPath, caption, cfg);
    paths.preview = previewPath;
end

end
