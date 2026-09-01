function [ok, reason] = canReuseKrMethodFromExport(methodDef, oldExport, oldMeta, newIds, ...
    currentContactFp, currentFitFp, currentZeroFp)
%canReuseKrMethodFromExport 既存 kr_table から方式列を再利用できるか

ok = false;
reason = "";

if nargin < 4 || isempty(oldExport) || ~istable(oldExport)
    reason = "no_export";
    return;
end
if nargin < 5 || isempty(oldMeta) || ~isstruct(oldMeta)
    reason = "no_metadata";
    return;
end

key = string(methodDef.key);
methodFp = krMethodFingerprint(methodDef);

if ~isfield(oldMeta, "krContactFingerprint") || ...
        string(oldMeta.krContactFingerprint) ~= string(currentContactFp)
    reason = "contact_changed";
    return;
end
if ~isfield(oldMeta, "krFitFingerprint") || ...
        string(oldMeta.krFitFingerprint) ~= string(currentFitFp)
    reason = "fit_changed";
    return;
end
if ~isfield(oldMeta, "zeroAdjustFingerprint") || ...
        string(oldMeta.zeroAdjustFingerprint) ~= string(currentZeroFp)
    reason = "zero_adjust_changed";
    return;
end

if ~isfield(oldMeta, "krMethodKeys") || ~any(string(oldMeta.krMethodKeys) == key)
    reason = "key_missing";
    return;
end

if ~methodFingerprintMatchesRegistry(methodFp, key, oldMeta)
    reason = "method_def_changed";
    return;
end

needCols = krMethodColumnNames(key);
colNames = string(oldExport.Properties.VariableNames);
if any(~ismember(needCols, colNames))
    reason = "columns_missing";
    return;
end

if ~ismember("id", colNames)
    reason = "id_missing";
    return;
end
if ~isequal(oldExport.id, newIds)
    [lia, ~] = ismember(newIds, oldExport.id);
    if ~all(lia)
        reason = "id_mismatch";
        return;
    end
end

ok = true;
reason = "reuse";

end

function ok = methodFingerprintMatchesRegistry(methodFp, key, oldMeta)
ok = false;
if isfield(oldMeta, "krMethodFingerprints") && isstruct(oldMeta.krMethodFingerprints)
    stored = oldMeta.krMethodFingerprints;
    if isfield(stored, matlab.lang.makeValidName(char(key)))
        fn = matlab.lang.makeValidName(char(key));
        ok = string(stored.(fn)) == string(methodFp);
        return;
    end
end
if ~isfield(oldMeta, "krRegistryFingerprint")
    return;
end
parts = split(string(oldMeta.krRegistryFingerprint), "|");
keyPrefix = key + ":";
match = parts(startsWith(parts, keyPrefix));
if isempty(match)
    return;
end
ok = match(1) == string(methodFp);
end

function cols = krMethodColumnNames(key)
cols = ["kr_" + key; "krLs_" + key; "krChord_" + key; ...
    "krDeltaLsMinusChord_" + key; "krSuccess_" + key; ...
    "krFitTier_" + key; "krFitR2_" + key; "krNBand_" + key];
end
