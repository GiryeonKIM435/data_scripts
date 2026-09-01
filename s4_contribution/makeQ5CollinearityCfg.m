function cvCfg = makeQ5CollinearityCfg(cfg)
%makeQ5CollinearityCfg VIF / 相関削減用設定

cvCfg = struct();
cvCfg.corrThreshold = 0.8;
cvCfg.vifThreshold = 10;
if isfield(cfg, "q5")
    if isfield(cfg.q5, "corrThreshold")
        cvCfg.corrThreshold = cfg.q5.corrThreshold;
    end
    if isfield(cfg.q5, "vifThreshold")
        cvCfg.vifThreshold = cfg.q5.vifThreshold;
    end
end

end
