function variants = resolveQ1KrVariants(cfg)
%resolveQ1KrVariants Q1 で評価する kr variant 一覧
%
% cfg.q1.krVariants が非空ならそれを使用。空なら cfg.deploy.krVariant のみ。

if nargin < 1 || isempty(cfg)
    cfg = PaperStudyConfig();
end

if isfield(cfg, "q1") && isfield(cfg.q1, "krVariants") && ~isempty(cfg.q1.krVariants)
    variants = string(cfg.q1.krVariants(:));
else
    variants = string(cfg.deploy.krVariant);
end

variants = unique(variants, "stable");

end
