function results = run_predictor_correlation(cfg, cohort, krCol, outDir, opts)
%RUN_PREDICTOR_CORRELATION 結果4.4: 対降伏点の相関・偏相関・共線性
%
% 予測変数順（本解析）: k ([5,35) N), c1(=c_M), k2(=k_K), c2(=c_K), weight, d_eq
%   - 対 F_yield の Pearson r / Spearman rho（bootstrap 95% CI）
%   - 偏相関（他の予測変数を統制、bootstrap 95% CI）
%   - VIF（共線性）
% を表（CSV + TeX/PNG）に、予測変数間の構造を Spearman 相関行列図に出力する。

if nargin < 5 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "expectedKrMethodKey")
    opts.expectedKrMethodKey = "force_s05_w30";
end
if ~isfield(opts, "krMethodKey")
    opts.krMethodKey = "";
end
if ~isfield(opts, "writeFigures")
    if isfield(cfg, "figures") && isfield(cfg.figures, "enabled")
        opts.writeFigures = logical(cfg.figures.enabled);
    else
        opts.writeFigures = true;
    end
end
writeFigures = logical(opts.writeFigures);
if isfield(cfg, "figures")
    cfg.figures.enabled = writeFigures;
end
if ~isfolder(outDir)
    mkdir(outDir);
end

krCol = string(krCol);
krMethodKey = string(opts.krMethodKey);
if strlength(krMethodKey) == 0
    krMethodKey = inferKrMethodKeyFromColumn(krCol);
end
expectedKey = string(opts.expectedKrMethodKey);
fprintf("4.4 correlation: krCol=%s, krMethodKey=%s (expected %s = [5, 35) N)\n", ...
    krCol, krMethodKey, expectedKey);
if strlength(expectedKey) > 0 && strlength(krMethodKey) > 0 ...
        && krMethodKey ~= expectedKey
    warning("run_predictor_correlation:UnexpectedKrInterval", ...
        ['Spearman/VIF in the paper assumes k on [5, 35) N (force_s05_w30), ' ...
        'but krMethodKey=%s. Check Q7 best / contribution resolution.'], ...
        char(krMethodKey));
end

tbl = cohort.predictorTable;
% データ列順: k, c1, k2, c2, weight, d_eq
predictors = [krCol; "c1"; "k2"; "c2"; "weight"; "d_eq"];
present = ismember(predictors, string(tbl.Properties.VariableNames));
if any(~present)
    error("run_predictor_correlation:MissingPredictors", ...
        "predictorTable に列がありません: %s", strjoin(predictors(~present), ", "));
end

% CSV 用表示名（記号寄り、TeX なし）
displayNames = ["k"; "c_M"; "k_K"; "c_K"; "weight"; "d_eq"];
% 図軸ラベル（LaTeX; TickLabelInterpreter=latex）
figTickLabels = [ ...
    "$F_{\mathrm{yield}}$"; ...
    "$k$"; ...
    "$c_{\mathrm{M}}$"; ...
    "$k_{\mathrm{K}}$"; ...
    "$c_{\mathrm{K}}$"; ...
    "$\mathrm{weight}$"; ...
    "$d_{\mathrm{eq}}$"];

X = tbl{:, predictors};
y = cohort.y(:);
valid = all(isfinite([X, y]), 2);
X = X(valid, :);
y = y(valid);
n = numel(y);
p = numel(predictors);

B = cfg.cv.bootstrapSamples;
alphaCi = 0.05;
rng(cfg.cv.bootstrapSeed);

[rPearson, pPearson] = corr(X, y, "Type", "Pearson");
[rSpearman, pSpearman] = corr(X, y, "Type", "Spearman");
ciPearson = bootstrapCorr(X, y, "Pearson", B, alphaCi);
ciSpearman = bootstrapCorr(X, y, "Spearman", B, alphaCi);

rPartial = nan(p, 1);
pPartial = nan(p, 1);
ciPartial = nan(p, 2);
vif = nan(p, 1);
for j = 1:p
    others = setdiff(1:p, j);
    [rPartial(j), pPartial(j)] = partialCorrelation(X(:, j), y, X(:, others));
    ciPartial(j, :) = bootstrapPartialCorr(X(:, j), y, X(:, others), B, alphaCi);
    vif(j) = computeVif(X(:, j), X(:, others));
end

corrTable = table(displayNames(:), ...
    rPearson, pPearson, ciPearson(:, 1), ciPearson(:, 2), ...
    rSpearman, pSpearman, ciSpearman(:, 1), ciSpearman(:, 2), ...
    rPartial, pPartial, ciPartial(:, 1), ciPartial(:, 2), vif, ...
    'VariableNames', {'predictor', ...
    'pearsonR', 'pearsonP', 'pearsonCiLo', 'pearsonCiHi', ...
    'spearmanRho', 'spearmanP', 'spearmanCiLo', 'spearmanCiHi', ...
    'partialR', 'partialP', 'partialCiLo', 'partialCiHi', 'vif'});
writetable(corrTable, fullfile(outDir, "predictor_correlation_vif.csv"));

% 論文貼付用の要約表（rho [CI], partial r [CI], VIF）
paperTable = table(displayNames(:), ...
    formatEstCi(rSpearman, ciSpearman, pSpearman), ...
    formatEstCi(rPartial, ciPartial, pPartial), ...
    arrayfun(@(v) string(sprintf("%.2f", v)), vif), ...
    'VariableNames', {'Predictor', 'Spearman rho [95% CI]', ...
    'Partial r [95% CI]', 'VIF'});
bundle = exportPaperTableBundle(paperTable, ...
    fullfile(outDir, "table4_4_predictor_correlation"), ...
    sprintf("Correlation with bioyield force (n=%d)", n), cfg);

% Spearman 相関行列（F_yield + 予測変数）
matNames = ["F_yield"; displayNames(:)];
matSpearman = corr([y, X], "Type", "Spearman");
matPearson = corr([y, X], "Type", "Pearson");
figPath = "";
if writeFigures
    figPath = plotCorrMatrixFigure(matSpearman, figTickLabels, cfg, ...
        fullfile(outDir, "fig4_4_spearman_corr_matrix.png"), "Spearman $\rho$");
end

results = struct();
results.createdAt = datetime("now");
results.n = n;
results.krCol = char(krCol);
results.krMethodKey = char(krMethodKey);
results.predictors = predictors;
results.displayNames = displayNames;
results.figTickLabels = figTickLabels;
results.corrTable = corrTable;
results.paperTable = paperTable;
results.paperTableBundle = bundle;
results.spearmanMatrix = matSpearman;
results.pearsonMatrix = matPearson;
results.matrixNames = matNames;
results.figPath = figPath;

save(fullfile(outDir, "predictor_correlation_results.mat"), "results", "-v7");
fprintf("4.4 correlation: n=%d, tables -> %s\n", n, outDir);
end

function key = inferKrMethodKeyFromColumn(krCol)
key = "";
s = string(krCol);
prefixes = ["krChord_", "krLs_", "kr_"];
for i = 1:numel(prefixes)
    pfx = prefixes(i);
    if startsWith(s, pfx)
        key = extractAfter(s, strlength(pfx));
        return;
    end
end
end

function v = computeVif(xj, Xothers)
valid = all(isfinite([xj, Xothers]), 2);
xj = xj(valid);
Xothers = Xothers(valid, :);
if numel(xj) < size(Xothers, 2) + 2
    v = nan;
    return;
end
Xd = [ones(numel(xj), 1), Xothers];
beta = Xd \ xj;
res = xj - Xd * beta;
ssRes = sum(res.^2);
ssTot = sum((xj - mean(xj)).^2);
if ssTot <= 0
    v = nan;
    return;
end
r2 = 1 - ssRes / ssTot;
v = 1 / max(1 - r2, eps);
end

function s = formatEstCi(est, ci, pVal)
n = numel(est);
s = strings(n, 1);
for i = 1:n
    s(i) = string(sprintf("%.2f [%.2f, %.2f]%s", est(i), ci(i, 1), ci(i, 2), ...
        significanceStarsLocal(pVal(i))));
end
end

function stars = significanceStarsLocal(pVal)
if ~isfinite(pVal)
    stars = "";
elseif pVal < 0.001
    stars = " ***";
elseif pVal < 0.01
    stars = " **";
elseif pVal < 0.05
    stars = " *";
else
    stars = "";
end
end
