function earlyTbl = countOnlineEarlyStopsByMethod(designPerSample, designSummary)
%countOnlineEarlyStopsByMethod 区間上端未到達による早期停止件数
%
% 定義: F_finalUpdate < (gridStart + gridWidth) - 0.5 N
% （完了割線に到達する前に停止した果実数。接触直後停止・帯入口停止を含む。）

if nargin < 1 || isempty(designPerSample)
    earlyTbl = emptyEarlyTable();
    return;
end
if nargin < 2 || isempty(designSummary)
    error("countOnlineEarlyStopsByMethod:MissingSummary", ...
        "designSummary（gridStart / gridWidth）が必要です。");
end

needPs = ["krMethodKey", "F_finalUpdate"];
needSum = ["krMethodKey", "gridStart", "gridWidth"];
for i = 1:numel(needPs)
    if ~ismember(needPs(i), designPerSample.Properties.VariableNames)
        error("countOnlineEarlyStopsByMethod:MissingCol", ...
            "designPerSample に列がありません: %s", needPs(i));
    end
end
for i = 1:numel(needSum)
    if ~ismember(needSum(i), designSummary.Properties.VariableNames)
        error("countOnlineEarlyStopsByMethod:MissingCol", ...
            "designSummary に列がありません: %s", needSum(i));
    end
end

keys = unique(string(designSummary.krMethodKey), "stable");
n = numel(keys);
krMethodKey = strings(n, 1);
nEarlyStop = zeros(n, 1);
nCohort = zeros(n, 1);
nNegPred = zeros(n, 1);
gridStart = nan(n, 1);
gridWidth = nan(n, 1);
bandHigh = nan(n, 1);

for i = 1:n
    key = keys(i);
    krMethodKey(i) = key;
    sumRow = designSummary(string(designSummary.krMethodKey) == key, :);
    if isempty(sumRow)
        continue;
    end
    fl = double(sumRow.gridStart(1));
    w = double(sumRow.gridWidth(1));
    gridStart(i) = fl;
    gridWidth(i) = w;
    bandHigh(i) = fl + w;
    thr = bandHigh(i) - 0.5;

    ps = designPerSample(string(designPerSample.krMethodKey) == key, :);
    nCohort(i) = height(ps);
    if nCohort(i) == 0
        continue;
    end
    fFinal = double(ps.F_finalUpdate);
    finiteF = isfinite(fFinal);
    nEarlyStop(i) = sum(finiteF & (fFinal < thr));
    if ismember("y_hat_finalUpdate", ps.Properties.VariableNames)
        yHat = double(ps.y_hat_finalUpdate);
        nNegPred(i) = sum(isfinite(yHat) & (yHat < 0));
    end
end

earlyTbl = table(krMethodKey, gridStart, gridWidth, bandHigh, ...
    nCohort, nEarlyStop, nNegPred);

end

function T = emptyEarlyTable()
T = table(strings(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    'VariableNames', {'krMethodKey', 'gridStart', 'gridWidth', 'bandHigh', ...
    'nCohort', 'nEarlyStop', 'nNegPred'});
end
