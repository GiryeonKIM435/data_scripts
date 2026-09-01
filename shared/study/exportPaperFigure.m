function exportPaperFigure(fig, pngPath, varargin)
%exportPaperFigure PNG と編集用 .fig を同時保存
%
% exportPaperFigure(fig, "path/to/fig1.png", "Resolution", 300)

if nargin < 2 || isempty(pngPath)
    error("exportPaperFigure:NoPath", "pngPath が必要です。");
end

pngPath = char(pngPath);
[outDir, name, ~] = fileparts(pngPath);
if strlength(string(outDir)) > 0 && ~isfolder(outDir)
    mkdir(outDir);
end

styleCfg = [];
exportArgs = varargin;
if ~isempty(varargin)
    keep = true(size(varargin));
    for vi = 1:2:numel(varargin)
        if vi + 1 <= numel(varargin) && strcmpi(varargin{vi}, "Cfg")
            styleCfg = varargin{vi + 1};
            keep(vi:vi + 1) = false;
        end
    end
    exportArgs = varargin(keep);
end
applyPaperFigureStyle(fig, styleCfg);

figPath = fullfile(outDir, [name, '.fig']);
% Visible=off のまま savefig すると、.fig を開いてもウィンドウが表示されない
fig.Visible = "on";
drawnow;

% exportgraphics の後に savefig すると、一部環境で .fig が開けないことがある
savefig(fig, figPath);

try
    exportgraphics(fig, pngPath, exportArgs{:});
catch ME
    close(fig);
    rethrow(ME);
end

figInfo = dir(figPath);
if isempty(figInfo) || figInfo.bytes < 100
    warning("exportPaperFigure:FigSaveFailed", ...
        ".fig の保存に失敗した可能性があります: %s", figPath);
end

close(fig);

end
