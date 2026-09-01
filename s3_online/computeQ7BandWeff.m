function weff = computeQ7BandWeff(mdef)
%computeQ7BandWeff 実行可能性ヒューリスティック用の有効帯域上端 [N]

t = string(mdef.type);
if t == "force_abs"
    if isfinite(mdef.highN)
        weff = double(mdef.highN);
    else
        weff = double(mdef.gridStart) + double(mdef.gridWidth);
    end
elseif t == "force_trailing"
    weff = double(mdef.offsetN) + double(mdef.widthN);
else
    weff = nan;
end
end
