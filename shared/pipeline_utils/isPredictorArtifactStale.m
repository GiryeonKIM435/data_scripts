function stale = isPredictorArtifactStale(matPath, mode)
%isPredictorArtifactStale MAT が現在の Registry 設定と一致するか
%
% mode: "analysis"（既定）| "cohort" | "auto"

stale = true;
if nargin < 1 || isempty(matPath) || ~isfile(matPath)
    return;
end
if nargin < 2 || isempty(mode)
    mode = inferArtifactStaleMode(matPath);
end
mode = lower(string(mode));

if mode == "cohort"
    currentFp = cohortRegistryFingerprint();
elseif mode == "analysis"
    currentFp = predictorRegistryFingerprint();
elseif mode == "auto"
    stale = isPredictorArtifactStale(matPath, inferArtifactStaleMode(matPath));
    return;
else
    error("isPredictorArtifactStale:BadMode", "mode は analysis / cohort / auto です。");
end

storedFp = readStoredFingerprint(matPath, mode);
if strlength(storedFp) > 0
    stale = storedFp ~= currentFp;
    if ~stale
        stale = isKrRegistryStaleForMaster(matPath);
    end
    return;
end

% レガシー MAT
if mode == "cohort"
  stale = true;
  return;
end
storedPreds = readStoredPredictors(matPath);
if isempty(storedPreds)
    stale = true;
    return;
end
reg = PredictorRegistry();
stale = ~isequal(sort(storedPreds(:)), sort(reg.paramPredictors(:)));
if stale
    return;
end
stale = isKrRegistryStaleForMaster(matPath);
end

function stale = isKrRegistryStaleForMaster(matPath)
stale = false;
if ~contains(lower(string(matPath)), "master_analysis")
    return;
end
try
    s = load(matPath, "metadata", "masterTable");
catch
    stale = true;
    return;
end
currentFp = krMethodRegistryFingerprint();
methods = KrMethodRegistry();
expectedKeys = sort(string({methods.key}));
meta = struct();
if isfield(s, "metadata")
    meta = s.metadata;
end

if isfield(meta, "krMethodKeys")
    if isKrRegistryFingerprintStale(meta, currentFp, expectedKeys)
        stale = true;
    end
    return;
end

if isfield(meta, "krRegistryFingerprint") && isUsableRegistryFingerprint(meta.krRegistryFingerprint) ...
        && isUsableRegistryFingerprint(currentFp)
    stale = string(meta.krRegistryFingerprint) ~= string(currentFp);
    if stale
        return;
    end
end

if ~isfield(s, "masterTable")
    stale = true;
    return;
end
colNames = string(s.masterTable.Properties.VariableNames);
need = "krChord_" + expectedKeys;
stale = any(~ismember(need, colNames));
end

function ok = isUsableRegistryFingerprint(fp)
ok = ~ismissing(fp) && strlength(string(fp)) > 0;
end

function mode = inferArtifactStaleMode(matPath)
p = lower(string(matPath));
if contains(p, "cohort_manifest")
    mode = "cohort";
elseif contains(p, "master_analysis")
    mode = "analysis";
else
    mode = "analysis";
end
end

function fp = readStoredFingerprint(matPath, mode)
fp = "";
try
    s = load(matPath);
    if mode == "cohort"
        if isfield(s, "manifest") && isfield(s.manifest, "cohortFingerprint")
            fp = string(s.manifest.cohortFingerprint);
        elseif isfield(s, "manifest") && isfield(s.manifest, "predictorFingerprint")
            fp = string(s.manifest.predictorFingerprint);
        end
        return;
    end
    if isfield(s, "metadata") && isfield(s.metadata, "predictorFingerprint")
        fp = string(s.metadata.predictorFingerprint);
    elseif isfield(s, "manifest") && isfield(s.manifest, "predictorFingerprint")
        fp = string(s.manifest.predictorFingerprint);
    end
catch
    fp = "";
end
end

function preds = readStoredPredictors(matPath)
preds = [];
try
    s = load(matPath);
    if isfield(s, "metadata") && isfield(s.metadata, "predictors")
        preds = string(s.metadata.predictors(:));
    elseif isfield(s, "manifest") && isfield(s.manifest, "predictors")
        preds = string(s.manifest.predictors(:));
    end
catch
    preds = [];
end
end
