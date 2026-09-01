function nDec = paperVarDecimals(varName)
%paperVarDecimals 変数ごとの論文表の小数桁

switch string(varName)
    case ["x", "y", "z"]
        nDec = 0;
    case "d_eq"
        nDec = 1;
    otherwise
        nDec = 1;
end

end
