function bestKey = resolveQ1BestMethodKey(q1Summary, cfg)
%resolveQ1BestMethodKey Q1 overall 最良 krMethodKey（deploy krVariant 行）

bestKey = "";
if nargin < 1 || isempty(q1Summary) || ~istable(q1Summary) || height(q1Summary) == 0
    return;
end

sub = q1Summary;
if nargin >= 2 && ~isempty(cfg) && isfield(cfg, "deploy") ...
        && isfield(cfg.deploy, "krVariant") ...
        && ismember("variant", sub.Properties.VariableNames)
    krVariant = string(cfg.deploy.krVariant);
    sub = sub(string(sub.variant) == krVariant, :);
end
if isempty(sub)
    sub = q1Summary;
end
if ~ismember("mae_loocv", sub.Properties.VariableNames)
    return;
end

sub = sortrows(sub, "mae_loocv", "ascend", "MissingPlacement", "last");
finiteRows = isfinite(sub.mae_loocv);
if ~any(finiteRows)
    return;
end
bestKey = char(string(sub.krMethodKey(find(finiteRows, 1, "first"))));

end
