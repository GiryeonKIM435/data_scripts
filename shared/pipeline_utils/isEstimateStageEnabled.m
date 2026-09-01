function enabled = isEstimateStageEnabled(opts)
%isEstimateStageEnabled RUN__pipeline の doEstimate 相当フラグ（未設定時は true）

enabled = true;
if nargin < 1 || isempty(opts)
    return;
end
if isfield(opts, "runStages") && isfield(opts.runStages, "doEstimate")
    enabled = logical(opts.runStages.doEstimate);
end

end
