function cacheDir = resolveDeployCacheDir(cfg, analysisTag)
%resolveDeployCacheDir analysisTag 別の共有キャチE��ュチE��レクトリ

if nargin < 2 || isempty(analysisTag)
    analysisTag = "burgers_iqr2";
end
cacheDir = fullfile(cfg.out.cache, char(analysisTag));
if ~isfolder(cacheDir)
    mkdir(cacheDir);
end

end
