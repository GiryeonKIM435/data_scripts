function fp = krMethodRegistryFingerprint()
%krMethodRegistryFingerprint KrMethodRegistry の内容指紋

methods = KrMethodRegistry();
parts = strings(numel(methods), 1);
for i = 1:numel(methods)
    parts(i) = krMethodFingerprint(methods(i));
end
parts = sort(parts);
fp = strjoin(parts, "|");

end
