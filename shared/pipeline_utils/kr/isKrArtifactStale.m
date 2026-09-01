function stale = isKrArtifactStale(krMatPath)
%isKrArtifactStale kr_table.mat が Registry / 接触 / フィット設定と不一致か

stale = false;
if nargin < 1 || ~isfile(krMatPath)
    stale = true;
    return;
end

currentRegistryFp = krMethodRegistryFingerprint();
currentContactFp = krContactConfigFingerprint();
currentFitFp = krFitConfigFingerprint();
currentZeroFp = yieldZeroAdjustFingerprint();
s = load(krMatPath, "metadata");
if ~isfield(s, "metadata")
    stale = true;
    return;
end
meta = s.metadata;

methods = KrMethodRegistry();
expectedKeys = sort(string({methods.key}));
expectedKeys = expectedKeys(:);

if isKrRegistryFingerprintStale(meta, currentRegistryFp, expectedKeys)
    stale = true;
    return;
end

if ~isfield(meta, "krContactFingerprint") || ...
        string(meta.krContactFingerprint) ~= string(currentContactFp)
    stale = true;
    return;
end

if ~isfield(meta, "krFitFingerprint") || ...
        string(meta.krFitFingerprint) ~= string(currentFitFp)
    stale = true;
    return;
end

if ~isfield(meta, "zeroAdjustFingerprint") || ...
        string(meta.zeroAdjustFingerprint) ~= string(currentZeroFp)
    stale = true;
    return;
end

if ~isfield(meta, "krMethodKeys")
    stale = true;
    return;
end
if ~isequal(sort(string(meta.krMethodKeys(:))), expectedKeys)
    stale = true;
end

end
