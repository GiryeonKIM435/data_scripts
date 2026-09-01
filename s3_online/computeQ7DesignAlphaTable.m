function [designTable, alphaByMethod, alphaPerSample] = computeQ7DesignAlphaTable(cfg, cohort, methodKeys, calibByKey, outDir)
%computeQ7DesignAlphaTable 外側foldごとの訓練コホート当てはめから α_design^(-i) を算出
%
% 外側fold i:
%   I_{-i} 上の LOO 係数 (a^(-i), b^(-i)) で各 j∈I_{-i} を予測
%   e_j^(-i) = max(0, (yHat_j^(-i) - y_j) / y_j)
%   ep^(-i) = quantile({e_j^(-i)}, p)
%   alpha_design^(-i) = (1 + ep^(-i)) * gamma
%
% 出力:
%   designTable    : 方式単位の要約（中央値 alpha 等、図表・最良選定用）
%   alphaByMethod  : nMethods × nSamples の fold 別 alpha
%   alphaPerSample : 長形式テーブル（方式×試料）

if nargin < 4
    calibByKey = [];
end
if nargin < 5
    outDir = "";
end

methods = KrMethodRegistry();
y = double(cohort.y(:));
tbl = cohort.predictorTable;
ids = cohort.ids(:);
krVariant = cfg.deploy.krVariant;
quantileP = cfg.q7.quantileP;
gamma = cfg.q7.gamma;
ymin = computeCohortYieldMin(y);
n = numel(y);

nMethods = numel(methodKeys);
alphaByMethod = nan(nMethods, n);
epByMethod = nan(nMethods, n);
rows = cell(nMethods, 24);
perSampleParts = cell(nMethods, 1);

for mi = 1:nMethods
    key = methodKeys(mi);
    mdef = lookupKrMethodRegistry(key, methods);
    [leakCat, leakNote] = krLeakageCategory(key, mdef);
    krCol = resolveDeployKrColumn(tbl, key, krVariant);
    krBatch = double(tbl.(krCol));

    keyChar = char(key);
    if ~isempty(calibByKey) && isa(calibByKey, "containers.Map") && isKey(calibByKey, keyChar)
        calib = calibByKey(keyChar);
    else
        calib = fitDeployCalibLoocv(krBatch, y);
    end

    [alphaVec, epVec] = computeTrainingCalibDesignAlpha(krBatch, y, calib, quantileP, gamma);
    alphaByMethod(mi, :) = alphaVec(:).';
    epByMethod(mi, :) = epVec(:).';

    alphaFinite = alphaVec(isfinite(alphaVec) & alphaVec > 0);
    epFinite = epVec(isfinite(epVec));
    if isempty(alphaFinite)
        alphaDesign = nan;
        epSummary = nan;
        alphaMin = nan;
        alphaMax = nan;
        alphaMean = nan;
    else
        alphaDesign = median(alphaFinite, "omitnan");
        epSummary = median(epFinite, "omitnan");
        alphaMin = min(alphaFinite);
        alphaMax = max(alphaFinite);
        alphaMean = mean(alphaFinite);
    end

    weff = computeQ7BandWeff(mdef);
    if isfinite(alphaDesign) && alphaDesign > 0 && isfinite(weff) && isfinite(ymin)
        margin = ymin / alphaDesign - weff;
        feasible = margin >= 0;
    else
        margin = nan;
        feasible = false;
    end

    yHat = nan(size(y));
    validCalib = isfinite(calib.a) & isfinite(calib.b) & isfinite(krBatch) & isfinite(y);
    yHat(validCalib) = calib.a(validCalib) .* krBatch(validCalib) + calib.b(validCalib);
    ok = isfinite(yHat) & isfinite(y) & (abs(y) > 0);
    metrics = calcMetrics(y(ok), yHat(ok));
    nOver = nnz(ok & (yHat > y));

    rows(mi, :) = { ...
        char(key), char(mdef.type), mdef.gridStart, mdef.gridWidth, logical(mdef.gridValid), ...
        char(mdef.label), char(leakCat), char(leakNote), ...
        weff, ymin, quantileP, gamma, epSummary, alphaDesign, ...
        alphaMean, alphaMin, alphaMax, logical(feasible), margin, ...
        metrics.mae, metrics.r2, nOver, nnz(ok), nnz(isfinite(alphaVec))};

    ps = table();
    ps.id = ids;
    ps.krMethodKey = repmat(string(key), n, 1);
    ps.alphaDesign = alphaVec(:);
    ps.ep = epVec(:);
    ps.label = repmat(string(mdef.label), n, 1);
    ps.methodType = repmat(string(mdef.type), n, 1);
    perSampleParts{mi} = ps;
end

designTable = cell2table(rows, 'VariableNames', { ...
    'krMethodKey', 'methodType', 'gridStart', 'gridWidth', 'gridValid', ...
    'label', 'leakCategory', 'leakNote', ...
    'bandHighWeff', 'ymin', 'quantileP', 'gamma', 'ep', 'alphaDesign', ...
    'alphaDesignMean', 'alphaDesignMin', 'alphaDesignMax', ...
    'feasible', 'feasibilityMargin', 'looMae', 'looR2', 'nOverestimate', ...
    'nLooValid', 'nAlphaValid'});

strCols = ["krMethodKey", "methodType", "label", "leakCategory", "leakNote"];
for si = 1:numel(strCols)
    c = strCols(si);
    designTable.(c) = fillmissing(string(designTable.(c)), "constant", "");
end

alphaPerSample = vertcat(perSampleParts{:});

if strlength(string(outDir)) > 0
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    writetable(designTable, fullfile(outDir, "q7_design_alpha_by_method.csv"));
    writetable(alphaPerSample, fullfile(outDir, "q7_design_alpha_per_sample.csv"));
end

end

function [alphaVec, epVec] = computeTrainingCalibDesignAlpha(kr, y, calib, quantileP, gamma)
%computeTrainingCalibDesignAlpha 訓練コホート当てはめ過大推定から fold 別 alpha を算出
%
% 外側fold i の (a^(-i), b^(-i)) = calib.a(i), calib.b(i) を用い、
% j∈I_{-i} への当てはめ過大推定の p 分位点から alpha を決める。

kr = double(kr(:));
y = double(y(:));
n = numel(y);
if numel(kr) ~= n
    error("computeTrainingCalibDesignAlpha:SizeMismatch", "kr と y の長さが一致しません。");
end
if ~isstruct(calib) || ~isfield(calib, "a") || ~isfield(calib, "b")
    error("computeTrainingCalibDesignAlpha:BadCalib", "calib に a, b が必要です。");
end

alphaVec = nan(n, 1);
epVec = nan(n, 1);

for i = 1:n
    if ~(isfinite(calib.a(i)) && isfinite(calib.b(i)))
        continue;
    end
    eTrain = nan(n, 1);
    for j = 1:n
        if j == i
            continue;
        end
        if ~(isfinite(kr(j)) && isfinite(y(j)) && abs(y(j)) > 0)
            continue;
        end
        yHat = calib.b(i) + calib.a(i) * kr(j);
        if ~isfinite(yHat)
            continue;
        end
        eTrain(j) = max(0, (yHat - y(j)) / abs(y(j)));
    end
    epVals = eTrain(isfinite(eTrain));
    if isempty(epVals)
        continue;
    end
    ep = quantile(epVals, quantileP);
    epVec(i) = ep;
    alphaVec(i) = (1 + ep) * gamma;
end

end
