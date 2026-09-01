function ok = isDeployCalibFoldValid(calib, foldIdx)
%isDeployCalibFoldValid LOO fold のキャリブがデプロイ可能か

ok = false;
if isempty(calib) || ~isstruct(calib)
    return;
end

if isfield(calib, "type") && string(calib.type) == "multivariate"
    if foldIdx < 1 || foldIdx > calib.n
        return;
    end
    ok = isfinite(calib.b0(foldIdx)) && all(isfinite(calib.beta(foldIdx, :)));
    return;
end

if isfield(calib, "a") && isfield(calib, "b")
    if foldIdx < 1 || foldIdx > numel(calib.a)
        return;
    end
    ok = isfinite(calib.a(foldIdx)) && isfinite(calib.b(foldIdx));
end

end
