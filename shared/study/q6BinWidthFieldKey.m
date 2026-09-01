function key = q6BinWidthFieldKey(binWidthN)
%q6BinWidthFieldKey ビン幅 [N] の struct フィールド名（例: 1 -> w01, 5 -> w05）

key = sprintf("w%02d", round(binWidthN));

end
