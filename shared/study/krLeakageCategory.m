function [category, leakNote] = krLeakageCategory(methodKey, methodDef)
%krLeakageCategory kr 方式のリーク区分ラベル

methodKey = string(methodKey);
if nargin < 2 || isempty(methodDef)
    methods = KrMethodRegistry();
    methodDef = [];
    for i = 1:numel(methods)
        if string(methods(i).key) == methodKey
            methodDef = methods(i);
            break;
        end
    end
    if isempty(methodDef)
        category = "unknown";
        leakNote = "未定義";
        return;
    end
end

switch string(methodDef.type)
    case "force_abs"
        category = "force_abs";
        leakNote = "deployable";
    case "time_abs"
        category = "time_abs";
        leakNote = "deployable";
    case "time_trailing"
        category = "time_trailing";
        leakNote = "deployable";
    case "force_trailing"
        category = "force_trailing";
        leakNote = "deployable";
    case "percent_yield"
        category = "percent_yield";
        leakNote = "causal_yhat_band";
    case "percent_def"
        category = "percent_def";
        leakNote = "oracle_yield_deformation";
    case "sliding_def"
        category = "sliding_def";
        leakNote = "deployable";
    case "percent_def_span"
        category = "percent_def_span";
        leakNote = "oracle_loading_span";
    otherwise
        category = "other";
        leakNote = "unknown";
end
end
