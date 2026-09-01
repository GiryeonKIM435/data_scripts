function ok = studyFingerprintsMatch(a, b)
%studyFingerprintsMatch キャッシュ指紋の比較（パス部はファイル名に正規化）
%
% yield_paper_study から移設したキャッシュを自己完結リポジトリでも再利用できる
% よう、fingerprint key に含まれる絶対パス（masterTable 等）はファイル名だけに
% 正規化して比較する。mtime・コホート ID・設定ハッシュ等はそのまま比較する。

ok = false;
if ~isstruct(a) || ~isstruct(b) || ~isfield(a, "key") || ~isfield(b, "key")
    return;
end
ok = strcmp(normalizeFingerprintKey(a.key), normalizeFingerprintKey(b.key));
end

function key = normalizeFingerprintKey(key)
key = char(string(key));
parts = strsplit(key, "|");
pathFields = ["masterTable", "cohortManifest", "tomatoDataset"];
for i = 1:numel(parts)
    for pf = pathFields
        prefix = char(pf + "=");
        if startsWith(parts{i}, prefix)
            rest = parts{i}(numel(prefix) + 1:end);
            [~, base, ext] = fileparts(rest);
            parts{i} = [prefix, char(string(base) + string(ext))];
            break;
        end
    end
end
key = char(strjoin(parts, "|"));
end
