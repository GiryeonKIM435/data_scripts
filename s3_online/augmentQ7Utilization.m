function [perSampleTable, summaryTable] = augmentQ7Utilization(perSampleTable, summaryTable)
%augmentQ7Utilization 後方互換ラッパ（→ augmentQ7OnlineSafetyMetrics）
[perSampleTable, summaryTable] = augmentQ7OnlineSafetyMetrics(perSampleTable, summaryTable);
end
