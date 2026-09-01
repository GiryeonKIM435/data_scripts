function labels = getQ5ModelCaseLabels(cfg) %#ok<INUSD>
%getQ5ModelCaseLabels Q5 8モデルの表示ラベル

labels = ["M0: kr"; "M_W: kr+weight"; "M_D: kr+d_{eq}"; "M_{c1}: kr+c1"; ...
    "M_{c2}: kr+c2"; "M_{k2}: kr+k2"; "M_J: kr+Jeffreys"; "M_{ALL}: full"];
end
