function traj = applyDeployCalibToSampleTrajectory(krPath, yTrue, calib, foldIdx, tbl, predictors)
%applyDeployCalibToSampleTrajectory 単変量 / 多変量キャリブを試料軌跡に適用

predictors = string(predictors(:));

if isstruct(calib) && isfield(calib, "type") && string(calib.type) == "multivariate"
    staticIdx = setdiff(1:numel(predictors), find(predictors == string(calib.krCol), 1));
    staticPreds = predictors(staticIdx);
    if isempty(staticPreds)
        staticRow = zeros(0, 1);
    else
        staticRow = tbl{foldIdx, cellstr(staticPreds)};
        staticRow = staticRow(:).';
    end
    traj = applyMultivariateDeployCalibToTrajectory(krPath, yTrue, calib, foldIdx, staticRow);
    return;
end

if isfield(calib, "a") && isfield(calib, "b")
    traj = applyDeployCalibToTrajectory(krPath, yTrue, calib.a(foldIdx), calib.b(foldIdx));
    return;
end

error("applyDeployCalibToSampleTrajectory:BadCalib", "未知の calib 形式です。");

end
