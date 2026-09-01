function fp = predictorRegistryFingerprint()
%predictorRegistryFingerprint 解析・master 列定義の指紋

reg = PredictorRegistry();
names = sort(reg.paramPredictors(:));
names = names(:).';
krKeys = sort(reg.krAnalyzeKeys(:));
krKeys = krKeys(:).';
outlierBase = reg.outlierBasePredictors(:);
gateNonKr = outlierBase(~startsWith(outlierBase, "kr_"));
gateNonKr = sort(gateNonKr);
gateNonKr = gateNonKr(:).';
parts = [string(reg.targetName), krKeys, names, "masterNonKr:" + gateNonKr];
fp = strjoin(parts, "|");

end
