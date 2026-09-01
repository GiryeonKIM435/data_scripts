function tag = q6BinWidthFileTag(binWidthN)
%q6BinWidthFileTag ビン幅 [N] の出力ファイル用タグ（例: 1 -> w01N, 5 -> w05N）

tag = sprintf("w%02dN", round(binWidthN));

end
