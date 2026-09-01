function cv = CvConfig()
%CvConfig 交差検証・RNG の共通設定

cv = struct();
cv.cvFolds = 6;
cv.cvSeed = 260416;
cv.splitSeed = 26041600;
cv.trainSeed = 26041601;
cv.bootstrapSamples = 5000;
cv.bootstrapSeed = 42;

% MLP
cv.mlpMaxEpochsFull = 200;
cv.mlpMaxEpochsCv = 80;
cv.mlpFastMode = false;
cv.mlpLayerSizesParams = [8, 4];
cv.mlpWaveformNPointsCv = 2048;  % fastMode 時は 512 に上書き可

% VIF / 相関削減
cv.corrThreshold = 0.90;
cv.vifThreshold = 10;

end
