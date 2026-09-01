function stale = isKrRegistryFingerprintStale(meta, currentFp, expectedKeys)
%isKrRegistryFingerprintStale Registry 指紋または key 一覧で stale 判定

expectedKeys = sort(string(expectedKeys(:)));

if isfield(meta, "krRegistryFingerprint")
    storedFp = meta.krRegistryFingerprint;
    if isUsableRegistryFingerprint(storedFp) && isUsableRegistryFingerprint(currentFp)
        stale = string(storedFp) ~= string(currentFp);
        return;
    end
end

if isfield(meta, "krMethodKeys")
    actualKeys = sort(string(meta.krMethodKeys(:)));
    stale = ~isequal(actualKeys, expectedKeys);
    return;
end

stale = true;
end

function ok = isUsableRegistryFingerprint(fp)
ok = ~ismissing(fp) && strlength(string(fp)) > 0;
end
