function logStudyProgress(prefix, done, total, label, tStart)
%logStudyProgress 進捗行を出力しコマンドウィンドウを即時更新

if nargin < 4 || isempty(label)
    label = "";
end
elapsed = toc(tStart);
pct = 100 * done / max(total, 1);
etaText = studyEtaText(done, total, elapsed);

if strlength(string(label)) > 0
    fprintf("%s: %d/%d (%.0f%%) %s | 経過 %.0fs, ETA %s\n", ...
        prefix, done, total, pct, label, elapsed, etaText);
else
    fprintf("%s: %d/%d (%.0f%%) | 経過 %.0fs, ETA %s\n", ...
        prefix, done, total, pct, elapsed, etaText);
end
drawnow("limitrate");

end

function text = studyEtaText(done, total, elapsed)
if done > 0 && done < total
    text = char(formatStudyEta(elapsed / done * (total - done)));
elseif done < total
    text = "算出中";
else
    text = "0s";
end
end

function text = formatStudyEta(sec)
if ~isfinite(sec) || sec < 0
    text = "算出中";
elseif sec < 90
    text = sprintf("%.0fs", sec);
elseif sec < 7200
    text = sprintf("%.0fmin", sec / 60);
else
    text = sprintf("%.1fh", sec / 3600);
end
end
