function fpStruct = buildKrMethodFingerprintStruct(methods)
%buildKrMethodFingerprintStruct 方式別指紋を struct に格納（field 名は makeValidName）

fpStruct = struct();
for i = 1:numel(methods)
    fn = matlab.lang.makeValidName(char(methods(i).key));
    fpStruct.(fn) = char(krMethodFingerprint(methods(i)));
end

end
