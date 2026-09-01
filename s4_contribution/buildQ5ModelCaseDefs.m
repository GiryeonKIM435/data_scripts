function cases = buildQ5ModelCaseDefs(cfg, krCol)
%buildQ5ModelCaseDefs Q5 予測モデル定義（M0〜M_ALL、8ケース）
%
% cases = buildQ5ModelCaseDefs(cfg, krCol)
%
% 各ケース:
%   modelId, caseId, label, candidates, protectedPredictors, collinearityMode

krCol = string(krCol);
burgers = cfg.burgersPredictors(:);
weightPred = "weight";
sizePred = "d_eq";

cases = struct("modelId", {}, "caseId", {}, "label", {}, "candidates", {}, ...
    "protectedPredictors", {}, "collinearityMode", {});

cases(end + 1) = mkCase("M0", "m0_kr", "kr only", krCol, krCol, "none"); %#ok<AGROW>
cases(end + 1) = mkCase("M_W", "m_w_kr_weight", "kr + weight", ...
    [krCol; weightPred], krCol, "none"); %#ok<AGROW>
cases(end + 1) = mkCase("M_D", "m_d_kr_deq", "kr + d_eq", ...
    [krCol; sizePred], krCol, "none"); %#ok<AGROW>
cases(end + 1) = mkCase("M_c1", "m_c1_kr_c1", "kr + c1", ...
    [krCol; "c1"], krCol, "none"); %#ok<AGROW>
cases(end + 1) = mkCase("M_c2", "m_c2_kr_c2", "kr + c2", ...
    [krCol; "c2"], krCol, "none"); %#ok<AGROW>
cases(end + 1) = mkCase("M_k2", "m_k2_kr_k2", "kr + k2", ...
    [krCol; "k2"], krCol, "none"); %#ok<AGROW>
cases(end + 1) = mkCase("M_B", "m_b_kr_burgers", "kr + burgers", ...
    [krCol; burgers], krCol, "none"); %#ok<AGROW>
cases(end + 1) = mkCase("M_ALL", "m_all_kr_full", "kr + all", ...
    [krCol; weightPred; sizePred; burgers], krCol, "fold_inner"); %#ok<AGROW>

end

function c = mkCase(modelId, caseId, label, candidates, protectedPredictors, collinearityMode)
c = struct();
c.modelId = string(modelId);
c.caseId = string(caseId);
c.label = string(label);
c.candidates = string(candidates(:));
c.protectedPredictors = string(protectedPredictors(:));
c.collinearityMode = string(collinearityMode);
end
