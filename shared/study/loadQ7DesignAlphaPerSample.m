function alphaVec = loadQ7DesignAlphaPerSample(cfg, krMethodKey, sampleIds, gammaTag, analysisTag)
%loadQ7DesignAlphaPerSample Q7 の fold 別 α_design^(-i) を試料順に返す
%
% alphaVec(i) は sampleIds(i) に対応する外側 fold の設計安全係数。

if nargin < 4 || strlength(string(gammaTag)) == 0
    gammaTag = "gamma_1p0";
    if isfield(cfg, "q5") && isfield(cfg.q5, "designAlphaGammaTag") ...
            && strlength(string(cfg.q5.designAlphaGammaTag)) > 0
        gammaTag = char(string(cfg.q5.designAlphaGammaTag));
    end
end
if nargin < 5 || strlength(string(analysisTag)) == 0
    analysisTag = resolvePaperQ3AnalysisTag(cfg);
end

csvPath = fullfile(cfg.out.q7, char(analysisTag), char(gammaTag), ...
    "q7_design_alpha_per_sample.csv");
if ~isfile(csvPath)
    error("loadQ7DesignAlphaPerSample:MissingCsv", ...
        "Q7 fold-alpha CSV がありません: %s", csvPath);
end

T = readtable(csvPath);
mask = string(T.krMethodKey) == string(krMethodKey);
T = T(mask, :);
if isempty(T)
    error("loadQ7DesignAlphaPerSample:NoMethod", ...
        "方式 %s の fold-alpha が CSV にありません: %s", krMethodKey, csvPath);
end

[tf, loc] = ismember(double(sampleIds(:)), double(T.id));
if ~all(tf)
    missing = sampleIds(~tf);
    error("loadQ7DesignAlphaPerSample:IdMismatch", ...
        "fold-alpha に無い試料 ID があります（例: %g）。", missing(1));
end

alphaVec = double(T.alphaDesign(loc));
alphaVec = alphaVec(:);
end
