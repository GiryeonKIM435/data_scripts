function applyPaperFigureStyle(fig, cfg)
%applyPaperFigureStyle A4 論文用の図スタイル（Times New Roman）

if nargin < 2 || isempty(cfg)
    cfg = PaperStudyConfig();
end

fontName = cfg.paper.fontName;
baseSz = cfg.paper.fontSizeBase;
legSz = cfg.paper.fontSizeLegend;
titleSz = cfg.paper.fontSizeTitle;
subtitleSz = cfg.paper.fontSizeSubtitle;

set(fig, ...
    "DefaultAxesFontName", fontName, ...
    "DefaultAxesFontSize", baseSz, ...
    "DefaultTextFontName", fontName, ...
    "DefaultTextFontSize", baseSz, ...
    "DefaultLegendFontName", fontName, ...
    "DefaultLegendFontSize", legSz);

axList = findall(fig, "Type", "axes");
for k = 1:numel(axList)
    ax = axList(k);
    if ~isprop(ax, "FontName")
        continue;
    end
    set(ax, "FontName", fontName, "FontSize", baseSz);
    if isprop(ax, "Title") && ~isempty(ax.Title.String)
        ax.Title.FontName = fontName;
        ax.Title.FontSize = titleSz;
    end
    if isprop(ax, "Subtitle") && ~isempty(ax.Subtitle.String)
        ax.Subtitle.FontName = fontName;
        ax.Subtitle.FontSize = subtitleSz;
    end
    if isprop(ax, "XLabel")
        ax.XLabel.FontName = fontName;
        ax.XLabel.FontSize = baseSz;
    end
    if isprop(ax, "YLabel")
        ax.YLabel.FontName = fontName;
        ax.YLabel.FontSize = baseSz;
    end
    if isprop(ax, "ZLabel")
        ax.ZLabel.FontName = fontName;
        ax.ZLabel.FontSize = baseSz;
    end
    set(ax, "TickLabelInterpreter", "none");
end

legList = findall(fig, "Type", "legend");
for k = 1:numel(legList)
    set(legList(k), "FontName", fontName, "FontSize", legSz);
end

cbList = findall(fig, "Type", "colorbar");
for k = 1:numel(cbList)
    cb = cbList(k);
    cb.FontName = fontName;
    cb.FontSize = baseSz;
    if isprop(cb, "Label")
        cb.Label.FontName = fontName;
        cb.Label.FontSize = baseSz;
    end
end

end
