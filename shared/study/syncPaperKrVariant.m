function cfg = syncPaperKrVariant(cfg)
%syncPaperKrVariant cfg.deploy.krVariant を paper / Q5 / Q7 / Q9 設定へ反映

if nargin < 1 || isempty(cfg)
    cfg = PaperStudyConfig();
end
if isfield(cfg, "deploy") && isfield(cfg.deploy, "krVariant")
    v = string(cfg.deploy.krVariant);
    cfg.paper.offlineKrVariant = v;
    if isfield(cfg, "q5")
        cfg.q5.krVariant = v;
    end
    if isfield(cfg, "q7")
        % analysisTag 空欄時は resolveQ7AnalysisTag → burgers_no_iqr（本解析）
    end
    if isfield(cfg, "q9")
        cfg.q9.krVariant = v;
    end
end

end
