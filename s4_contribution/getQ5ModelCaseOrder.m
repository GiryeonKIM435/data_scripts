function order = getQ5ModelCaseOrder(cfg) %#ok<INUSD>
%getQ5ModelCaseOrder Q5 8モデルの表示順

order = ["m0_kr"; "m_w_kr_weight"; "m_d_kr_deq"; "m_c1_kr_c1"; "m_c2_kr_c2"; ...
    "m_k2_kr_k2"; "m_b_kr_burgers"; "m_all_kr_full"];
end
