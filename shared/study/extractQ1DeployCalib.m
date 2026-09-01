function calibCell = extractQ1DeployCalib(q1Results)
%extractQ1DeployCalib Q1 結果から deploy LOO calib セルを取得

if isfield(q1Results, "deployCalib") && ~isempty(q1Results.deployCalib)
    calibCell = q1Results.deployCalib;
elseif isfield(q1Results, "deployCalibChord") && ~isempty(q1Results.deployCalibChord)
    calibCell = q1Results.deployCalibChord;
else
    calibCell = {};
end

end
