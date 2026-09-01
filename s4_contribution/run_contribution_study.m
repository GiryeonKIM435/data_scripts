function results = run_contribution_study(cfg, opts)
%RUN_CONTRIBUTION_STUDY Results 4.4: additional predictors
%
% Products:
%   - Spearman / VIF table + correlation matrix
%   - post-test LOOCV multi-panel scatter (no sequential online Q5 track)
%
% Stiffness interval k follows Q7 force_abs best unless opts override.

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "useOutlierFilter")
    opts.useOutlierFilter = cfg.q5.useOutlierFilter;
end
if ~isfield(opts, "writeFigures")
    opts.writeFigures = true;
end
writeFigures = logical(opts.writeFigures);
cfg.figures.enabled = writeFigures;

if isfield(opts, "analysisTag") && strlength(string(opts.analysisTag)) > 0
    analysisTag = char(string(opts.analysisTag));
elseif isfield(cfg, "paper") && isfield(cfg.paper, "q3AnalysisTag") ...
        && strlength(string(cfg.paper.q3AnalysisTag)) > 0
    analysisTag = char(string(cfg.paper.q3AnalysisTag));
else
    analysisTag = resolvePaperQ3AnalysisTag(cfg);
end

%% Resolve k (default: Q7 force_abs best for both offline track + Spearman)
if isfield(opts, "onlineKrMethodKey") && strlength(string(opts.onlineKrMethodKey)) > 0
    onlineKey = string(opts.onlineKrMethodKey);
    alphaDesign = cfg.q5.primaryAlpha;
    onlineSource = "opts.onlineKrMethodKey";
    if isfield(opts, "alphaDesign") && isfinite(opts.alphaDesign)
        alphaDesign = opts.alphaDesign;
    end
else
    [onlineKey, alphaDesign, onlineSource] = resolveOnlineBestFromQ7(cfg, analysisTag);
end
if isfield(opts, "offlineKrMethodKey") && strlength(string(opts.offlineKrMethodKey)) > 0
    offlineKey = string(opts.offlineKrMethodKey);
    offlineSource = "opts.offlineKrMethodKey";
elseif isfield(opts, "useQ1OfflineBestForOfflineTrack") ...
        && logical(opts.useQ1OfflineBestForOfflineTrack)
    [offlineKey, offlineSource] = resolveOfflineBestFromQ1(cfg, analysisTag);
else
    offlineKey = onlineKey;
    offlineSource = "same_as_online_best";
end
onlineKey = sanitizeMethodKey(onlineKey, string(cfg.q5.onlineTrackKrMethodKey));
offlineKey = sanitizeMethodKey(offlineKey, onlineKey);
onlineSource = sanitizePrintString(onlineSource, "config fallback");
offlineSource = sanitizePrintString(offlineSource, "same_as_online_best");
if ~(isfinite(alphaDesign) && alphaDesign > 0)
    alphaDesign = cfg.q5.primaryAlpha;
end

fprintf("4.4 additional predictors: kr = %s (%s)\n", char(onlineKey), char(onlineSource));
fprintf("4.4 post-test track kr = %s (%s)\n", char(offlineKey), char(offlineSource));

cfg.q5.krMethodKey = onlineKey;
cfg.q5.onlineTrackKrMethodKey = onlineKey;
cfg.q5.offlineBestKrMethodKey = offlineKey;
cfg.q5.offlineTrackKrMethodKey = offlineKey;
cfg.q5.perSampleDesignAlpha = true;
gammaTag = "gamma_" + strrep(sprintf("%.1f", cfg.q7.gammaValues(1)), ".", "p");
cfg.q5.designAlphaGammaTag = char(gammaTag);
if isfinite(alphaDesign) && alphaDesign > 0
    cfg.q5.primaryAlpha = alphaDesign;
    cfg.q5.onlineScatterAlpha = alphaDesign;
end

q5Results = run_q5_predictor_deploy_study(cfg, struct( ...
    "useOutlierFilter", opts.useOutlierFilter, ...
    "q3AnalysisTag", analysisTag, ...
    "paperPostTestOnly", true, ...
    "offlineKrMethodKey", offlineKey, ...
    "onlineKrMethodKey", onlineKey));

corrOutDir = fullfile(cfg.out.q5, analysisTag);
corrResults = run_predictor_correlation(cfg, q5Results.cohort, ...
    q5Results.offlineKrCol, corrOutDir, struct( ...
    "krMethodKey", offlineKey, ...
    "expectedKrMethodKey", "force_s05_w30", ...
    "writeFigures", writeFigures));

results = struct();
results.createdAt = datetime("now");
results.analysisTag = analysisTag;
results.onlineKrMethodKey = char(onlineKey);
results.offlineKrMethodKey = char(offlineKey);
results.alphaDesign = alphaDesign;
results.q5 = q5Results;
results.correlation = corrResults;
results.outputDir = fullfile(cfg.out.q5, analysisTag);

fprintf("4.4 additional predictors finished: %s\n", results.outputDir);
end

function [key, alphaDesign, source] = resolveOnlineBestFromQ7(cfg, analysisTag)
key = string(cfg.q5.onlineTrackKrMethodKey);
alphaDesign = cfg.q5.primaryAlpha;
source = "config fallback";

gammaTag = "gamma_" + strrep(sprintf("%.1f", cfg.q7.gammaValues(1)), ".", "p");
csvPath = fullfile(cfg.out.q7, analysisTag, gammaTag, "q7_design_best_by_scope.csv");
if ~isfile(csvPath)
    return;
end
tbl = readtable(csvPath);
row = tbl(string(tbl.scope) == "force_abs", :);
cand = "";
if ~isempty(row)
    cand = string(row.krMethodKey(1));
end
if ismissing(cand) || strlength(cand) == 0
    return;
end
key = cand;
alpha = row.alphaDesign(1);
if isfinite(alpha) && alpha > 0
    alphaDesign = alpha;
end
source = "Q7 " + gammaTag + " best (Final-update MAE)";
end

function key = sanitizeMethodKey(key, fallback)
key = string(key);
if ismissing(key) || strlength(key) == 0
    key = string(fallback);
end
if ismissing(key) || strlength(key) == 0
    key = "force_s05_w30";
end
end

function s = sanitizePrintString(s, fallback)
s = string(s);
if ismissing(s) || strlength(s) == 0
    s = string(fallback);
end
end

function [key, source] = resolveOfflineBestFromQ1(cfg, analysisTag)
key = string(cfg.q5.offlineBestKrMethodKey);
source = "config fallback";

q1Summary = loadQ1SummaryTable(cfg, analysisTag);
if isempty(q1Summary) || height(q1Summary) == 0
    return;
end
sub = q1Summary;
if ismember("variant", sub.Properties.VariableNames)
    sub = sub(string(sub.variant) == string(cfg.deploy.krVariant), :);
end
sub = sub(string(sub.methodType) == "force_abs" & isfinite(sub.mae_loocv), :);
if ismember("gridValid", sub.Properties.VariableNames)
    sub = sub(logical(sub.gridValid), :);
end
if isempty(sub)
    return;
end
[~, idx] = min(sub.mae_loocv);
key = string(sub.krMethodKey(idx));
source = "Q1 best force_abs (LOOCV MAE)";
end
