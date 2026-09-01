function m = lookupKrMethodRegistry(key, methods)
%lookupKrMethodRegistry KrMethodRegistry から key で方式定義を取得

if nargin < 2 || isempty(methods)
    methods = KrMethodRegistry();
end

key = string(key);
for i = 1:numel(methods)
    if string(methods(i).key) == key
        m = methods(i);
        return;
    end
end

error("lookupKrMethodRegistry:UnknownKey", ...
    "未知の kr 方式 key です: %s", key);

end
