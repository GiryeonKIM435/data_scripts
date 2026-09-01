function fp = krMethodFingerprint(m)
%krMethodFingerprint 単一 kr 方式の内容指紋（Registry 行と 1:1）

switch string(m.type)
    case "percent_yield"
        band = sprintf("%.8g,%.8g", m.lowFrac, m.highFrac);
    case "force_abs"
        band = sprintf("%.8g,%.8g", m.lowN, m.highN);
    case "time_abs"
        band = sprintf("%.8g,%.8g", m.lowSec, m.highSec);
    case "time_trailing"
        band = sprintf("%.8g,%.8g", m.offsetSec, m.widthSec);
    case "force_trailing"
        band = sprintf("%.8g,%.8g", m.offsetN, m.widthN);
    otherwise
        band = "";
end
fp = string(m.key) + ":" + string(m.type) + ":" + band + ":" + string(m.gridValid);

end
