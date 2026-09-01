function opts = mergeRunOptions(userOpts)
%MERGERUNOPTIONS userOpts を defaultRunOptions に deep-merge

if nargin < 1 || isempty(userOpts)
    opts = defaultRunOptions();
    return;
end
opts = defaultRunOptions();
opts = mergeStructRecursive(opts, userOpts);
end

function base = mergeStructRecursive(base, over)
if ~isstruct(over)
    return;
end
fn = fieldnames(over);
for i = 1:numel(fn)
    key = fn{i};
    if isstruct(over.(key)) && isfield(base, key) && isstruct(base.(key))
        base.(key) = mergeStructRecursive(base.(key), over.(key));
    else
        base.(key) = over.(key);
    end
end
end
