function [tbl, info] = filterKrSummaryToRegistry(tbl, cfg, label)
%filterKrSummaryToRegistry サマリ表を現行 KrMethodRegistry の方式に限定

info = struct("label", "", "nDropped", 0, "nMissing", 0, "droppedKeys", string.empty(0, 1), ...
    "missingKeys", string.empty(0, 1));

if nargin < 3
    label = "";
end
info.label = char(string(label));

if isempty(tbl) || ~istable(tbl) || ~ismember("krMethodKey", tbl.Properties.VariableNames)
    return;
end

if nargin < 2 || isempty(cfg)
    cfg = PaperStudyConfig();
end

expected = string(cfg.krMethodKeys(:));
present = unique(string(tbl.krMethodKey));
extra = setdiff(present, expected);
missing = setdiff(expected, present);

info.droppedKeys = extra(:);
info.missingKeys = missing(:);
info.nDropped = numel(extra);
info.nMissing = numel(missing);

if info.nDropped > 0
    tag = strlength(string(label)) > 0;
    if tag
        fprintf("Q0: %s — Registry 外の方式を除外 (%d)\n", label, info.nDropped);
    else
        fprintf("Q0: Registry 外の方式を除外 (%d)\n", info.nDropped);
    end
end
if info.nMissing > 0
    if strlength(string(label)) > 0
        fprintf("Q0 警告: %s に未計算の Registry 方式 (%d)。Q1/Q3 の再実行を推奨。\n", ...
            label, info.nMissing);
    else
        fprintf("Q0 警告: Registry 方式が結果に未含 (%d)。Q1/Q3 の再実行を推奨。\n", ...
            info.nMissing);
    end
end

keep = ismember(string(tbl.krMethodKey), expected);
tbl = tbl(keep, :);

end
