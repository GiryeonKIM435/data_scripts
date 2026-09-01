function krVal = resolveTrajectoryKrAt(krPath, t)
%resolveTrajectoryKrAt 軌跡上の kr 値（krDeploy 優先、旧 krChord 互換）

krVal = nan;
if isfield(krPath, "krDeploy") && numel(krPath.krDeploy) >= t
    krVal = krPath.krDeploy(t);
elseif isfield(krPath, "krChord") && numel(krPath.krChord) >= t
    krVal = krPath.krChord(t);
end

end
