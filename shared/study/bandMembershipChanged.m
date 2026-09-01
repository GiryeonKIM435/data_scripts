function tf = bandMembershipChanged(prevMask, currMask)
%bandMembershipChanged 帯域内点集合が変わったか（prefix 伸長・境界シフトを含む）

if isempty(prevMask)
    tf = any(currMask);
    return;
end
nPrev = numel(prevMask);
nCurr = numel(currMask);
if nCurr < nPrev
    tf = true;
    return;
end
if any(prevMask ~= currMask(1:nPrev))
    tf = true;
    return;
end
tf = any(currMask(nPrev + 1:end));

end
