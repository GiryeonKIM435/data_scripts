function tbl = buildMasterPredictorTable(tomatoDataWithFit, krTable)
%BUILDMASTERPREDICTORTABLE Merge Jeffreys summary + k columns by id

baseTbl = buildTomatoPredictorTable(tomatoDataWithFit);
reg = PredictorRegistry();
predictors = reg.paramPredictors;
methods = KrMethodRegistry();

if istable(krTable) && ismember("id", krTable.Properties.VariableNames)
    [found, loc] = ismember(baseTbl.id, krTable.id);
    for m = 1:numel(methods)
        key = string(methods(m).key);
        krCol = "kr_" + key;
        lsCol = "krLs_" + key;
        chordCol = "krChord_" + key;
        deltaCol = "krDeltaLsMinusChord_" + key;
        succCol = "krSuccess_" + key;
        vals = nan(height(baseTbl), 1);
        valsLs = nan(height(baseTbl), 1);
        valsChord = nan(height(baseTbl), 1);
        valsDelta = nan(height(baseTbl), 1);
        if ismember(krCol, krTable.Properties.VariableNames)
            vals(found) = krTable.(krCol)(loc(found));
            if ismember(lsCol, krTable.Properties.VariableNames)
                valsLs(found) = krTable.(lsCol)(loc(found));
            else
                valsLs(found) = vals(found);
            end
            if ismember(chordCol, krTable.Properties.VariableNames)
                valsChord(found) = krTable.(chordCol)(loc(found));
            end
            if ismember(deltaCol, krTable.Properties.VariableNames)
                valsDelta(found) = krTable.(deltaCol)(loc(found));
            else
                valsDelta(found) = valsLs(found) - valsChord(found);
            end
            if ismember(succCol, krTable.Properties.VariableNames)
                bad = ~krTable.(succCol)(loc(found));
                vals(found & bad) = nan;
                valsLs(found & bad) = nan;
                valsChord(found & bad) = nan;
                valsDelta(found & bad) = nan;
            end
        end
        baseTbl.(krCol) = vals;
        baseTbl.(lsCol) = valsLs;
        baseTbl.(chordCol) = valsChord;
        baseTbl.(deltaCol) = valsDelta;
    end
else
    for m = 1:numel(methods)
        key = string(methods(m).key);
        baseTbl.("kr_" + key) = nan(height(baseTbl), 1);
        baseTbl.("krLs_" + key) = nan(height(baseTbl), 1);
        baseTbl.("krChord_" + key) = nan(height(baseTbl), 1);
        baseTbl.("krDeltaLsMinusChord_" + key) = nan(height(baseTbl), 1);
    end
end

allKrCols = "kr_" + string({methods.key});
allLsCols = "krLs_" + string({methods.key});
allChordCols = "krChord_" + string({methods.key});
allDeltaCols = "krDeltaLsMinusChord_" + string({methods.key});
isKrPred = startsWith(predictors, "kr_") | startsWith(predictors, "krLs_") | startsWith(predictors, "krChord_");
krPreds = predictors(isKrPred);
missingKr = krPreds(~ismember(krPreds, string(baseTbl.Properties.VariableNames)));
if ~isempty(missingKr)
    error("buildMasterPredictorTable:MissingKr", ...
        "kr_table に必要な列がありません: %s", strjoin(missingKr, ", "));
end

outlierBase = reg.outlierBasePredictors(:);
paramNonKr = predictors(~startsWith(predictors, "kr_"));
gateNonKr = outlierBase(~startsWith(outlierBase, "kr_"));
nonKrPreds = unique([paramNonKr(:); gateNonKr(:)], "stable");
keepCols = unique(["id", "yieldPointN", nonKrPreds(:).', allKrCols(:).', allLsCols(:).', allChordCols(:).', allDeltaCols(:).'], "stable");
keepCols = keepCols(ismember(keepCols, string(baseTbl.Properties.VariableNames)));
tbl = baseTbl(:, keepCols);

end
