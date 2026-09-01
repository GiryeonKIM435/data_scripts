function branch = orderDeployBranchSeries(branch, timeOrder)
%orderDeployBranchSeries loading 枝の (def, force, sec) を時系列順に並べ替え

if nargin < 2 || isempty(timeOrder)
    timeOrder = "sec_asc";
end

def = branch.defLoad(:);
force = branch.forceLoad(:);
if isfield(branch, "secLoad")
    sec = branch.secLoad(:);
else
    sec = (1:numel(def)).';
end

switch string(timeOrder)
    case "sec_asc"
        [sec, ord] = sort(sec, "ascend");
    case "index"
        ord = (1:numel(def)).';
        sec = sec(ord);
    case "def_asc"
        [~, ord] = sort(def, "ascend");
        sec = sec(ord);
    otherwise
        error("orderDeployBranchSeries:BadOrder", "未知の timeOrder: %s", timeOrder);
end

branch.defLoad = def(ord);
branch.forceLoad = force(ord);
branch.secLoad = sec(ord);

end
