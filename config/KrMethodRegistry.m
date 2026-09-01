function methods = KrMethodRegistry()
%KrMethodRegistry kr 推定方式の定義（編集して区間を追加・変更）
%
% グリッドはヒートマップ可読性のため整理。
% force_abs は帯域上限を設けず、推定失敗はデプロイ側で fail として集計。
% time_abs / time_trailing は廃止（低レベル fit 実装は残すが Registry には登録しない）。

startsPct = [0 10 25 50 75 90];
widthsPct = [5 10 25 50 75 100];
startsForce = [0 5 10 20 30];
widthsForce = [1 3 5 10 20 30];

methods = repmat(krPct("", 0, 0.05, "", 0, 5, true), 0, 1);
for s = startsPct
    for w = widthsPct
        hi = s + w;
        if hi > 100
            continue;
        end
        key = sprintf("pct_s%02d_w%02d", s, w);
        label = sprintf("yield%% [%d, %d)", s, hi);
        methods(end + 1) = krPct(key, s / 100, hi / 100, label, s, w, true); %#ok<AGROW>
    end
end
for s = startsForce
    for w = widthsForce
        hi = s + w;
        key = sprintf("force_s%02d_w%02d", s, w);
        isValid = w > 0;
        label = sprintf("force [%.0f, %.0f) N", s, hi);
        methods(end + 1) = krForce(key, s, hi, label, s, w, isValid); %#ok<AGROW>
    end
end

offsetsForce = [0 5 10 20 30];
widthsTrailForce = [1 3 5 10 20 30];
for f = offsetsForce
    for w = widthsTrailForce
        key = sprintf("ftrail_f%02d_w%02d", f, w);
        isValid = w > 0 && f >= 0;
        label = sprintf("trail force [F-%.0f-%.0f, F-%.0f) N", f, w, f);
        methods(end + 1) = krForceTrailing(key, f, w, label, f, w, isValid); %#ok<AGROW>
    end
end

validateKrMethodRegistry(methods);

end

function m = krPct(key, lowFrac, highFrac, label, gridStart, gridWidth, gridValid)
m = struct("key", key, "type", "percent_yield", ...
    "lowFrac", lowFrac, "highFrac", highFrac, ...
    "lowN", nan, "highN", nan, "lowSec", nan, "highSec", nan, ...
    "offsetSec", nan, "widthSec", nan, "offsetN", nan, "widthN", nan, ...
    "label", label, ...
    "gridStart", gridStart, "gridWidth", gridWidth, "gridValid", logical(gridValid));
end

function m = krForce(key, lowN, highN, label, gridStart, gridWidth, gridValid)
m = struct("key", key, "type", "force_abs", ...
    "lowFrac", nan, "highFrac", nan, ...
    "lowN", lowN, "highN", highN, "lowSec", nan, "highSec", nan, ...
    "offsetSec", nan, "widthSec", nan, "offsetN", nan, "widthN", nan, ...
    "label", label, ...
    "gridStart", gridStart, "gridWidth", gridWidth, "gridValid", logical(gridValid));
end

function m = krTime(key, lowSec, highSec, label, gridStart, gridWidth, gridValid)
m = struct("key", key, "type", "time_abs", ...
    "lowFrac", nan, "highFrac", nan, ...
    "lowN", nan, "highN", nan, "lowSec", lowSec, "highSec", highSec, ...
    "offsetSec", nan, "widthSec", nan, "offsetN", nan, "widthN", nan, ...
    "label", label, ...
    "gridStart", gridStart, "gridWidth", gridWidth, "gridValid", logical(gridValid));
end

function m = krTimeTrailing(key, offsetSec, widthSec, label, gridStart, gridWidth, gridValid)
m = struct("key", key, "type", "time_trailing", ...
    "lowFrac", nan, "highFrac", nan, ...
    "lowN", nan, "highN", nan, "lowSec", nan, "highSec", nan, ...
    "offsetSec", offsetSec, "widthSec", widthSec, "offsetN", nan, "widthN", nan, ...
    "label", label, ...
    "gridStart", gridStart, "gridWidth", gridWidth, "gridValid", logical(gridValid));
end

function m = krForceTrailing(key, offsetN, widthN, label, gridStart, gridWidth, gridValid)
m = struct("key", key, "type", "force_trailing", ...
    "lowFrac", nan, "highFrac", nan, ...
    "lowN", nan, "highN", nan, "lowSec", nan, "highSec", nan, ...
    "offsetSec", nan, "widthSec", nan, "offsetN", offsetN, "widthN", widthN, ...
    "label", label, ...
    "gridStart", gridStart, "gridWidth", gridWidth, "gridValid", logical(gridValid));
end

function validateKrMethodRegistry(methods)
keys = string({methods.key});
if numel(unique(keys)) ~= numel(keys)
    error("KrMethodRegistry:DuplicateKey", "重複する key があります。");
end
for i = 1:numel(methods)
    m = methods(i);
    if m.type == "percent_yield"
        if ~(isfinite(m.lowFrac) && isfinite(m.highFrac) && m.lowFrac < m.highFrac)
            error("KrMethodRegistry:BadPercent", "不正な %% 区間: %s", m.key);
        end
    elseif m.type == "force_abs"
        if ~(isfinite(m.lowN) && isfinite(m.highN) && m.lowN < m.highN)
            error("KrMethodRegistry:BadForce", "不正な力区間: %s", m.key);
        end
    elseif m.type == "time_abs"
        if ~(isfinite(m.lowSec) && isfinite(m.highSec) && m.lowSec < m.highSec)
            error("KrMethodRegistry:BadTime", "不正な時間区間: %s", m.key);
        end
    elseif m.type == "time_trailing"
        if ~(isfinite(m.offsetSec) && isfinite(m.widthSec) && m.offsetSec >= 0 && m.widthSec > 0)
            error("KrMethodRegistry:BadTimeTrailing", "不正な trailing 時間: %s", m.key);
        end
    elseif m.type == "force_trailing"
        if ~(isfinite(m.offsetN) && isfinite(m.widthN) && m.offsetN >= 0 && m.widthN > 0)
            error("KrMethodRegistry:BadForceTrailing", "不正な trailing 力: %s", m.key);
        end
    else
        error("KrMethodRegistry:BadType", "未知の type: %s", m.key);
    end
end
end
