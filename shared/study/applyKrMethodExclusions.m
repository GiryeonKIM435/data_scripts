function cfg = applyKrMethodExclusions(cfg, excludeTypes)
%applyKrMethodExclusions cfg.krMethodKeys から指定 type を除外

if nargin < 2 || isempty(excludeTypes)
    excludeTypes = string.empty(0, 1);
else
    % char 行ベクトルを string(char(:)) すると1文字ずつになるため、先に string 化する
    excludeTypes = string(excludeTypes);
    excludeTypes = excludeTypes(:);
end
if ~isfield(cfg, "analysis") || ~isstruct(cfg.analysis)
    cfg.analysis = struct();
end
cfg.analysis.excludeKrMethodTypes = excludeTypes;

if isempty(excludeTypes)
    return;
end

methods = KrMethodRegistry();
cfg.krMethodKeys = filterActiveKrMethodKeys(cfg.krMethodKeys, methods, excludeTypes);

if isfield(cfg, "paper") && isstruct(cfg.paper)
    cfg.paper = clearExcludedPaperMethodKeys(cfg.paper, excludeTypes, methods);
end

fprintf("stiffness-method exclusion (%s): %d methods remain\n", ...
    strjoin(excludeTypes, ", "), numel(cfg.krMethodKeys));

end

function paper = clearExcludedPaperMethodKeys(paper, excludeTypes, methods)
keyFields = ["offlineKrMethodKey", "exampleMethodKey"];
for i = 1:numel(keyFields)
    fieldName = keyFields(i);
    if ~isfield(paper, fieldName)
        continue;
    end
    key = string(paper.(fieldName));
    if strlength(key) == 0
        continue;
    end
    mdef = lookupKrMethodRegistry(key, methods);
    if ismember(string(mdef.type), excludeTypes)
        paper.(fieldName) = "";
    end
end

if isfield(paper, "exampleMethodKeysByType") && isstruct(paper.exampleMethodKeysByType)
  for t = excludeTypes
      tChar = char(t);
      if isfield(paper.exampleMethodKeysByType, tChar)
          paper.exampleMethodKeysByType.(tChar) = "";
      end
  end
end

end
