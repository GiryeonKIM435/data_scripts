function q9 = resolveQ9Settings(cfg)
%resolveQ9Settings Q9 力閾値レジーム切替の設定を解決・検証

q9 = struct();
q9.switchForceN = 35;
q9.lowMethodKey = "force_s00_w20";
q9.highMethodKey = "ftrail_f30_w30";
q9.krVariant = "chord";
q9.alphaValues = [1.5; 2; 3];
q9.primaryAlpha = 2;
q9.analysisTag = "piecewise_f35_s00w20_f30w30";
q9.useOutlierFilter = true;
q9.reuseCache = true;
q9.saveTrajectoryCache = true;
q9.parallelSamples = true;
q9.doFigSamples = true;
q9.nFigSamples = 5;
q9.figSampleIds = [1; 18; 29; 42; 83];

if nargin < 1 || isempty(cfg)
    validateQ9MethodKeys(q9);
    return;
end

if isfield(cfg, "deploy")
    q9.krVariant = cfg.deploy.krVariant;
    q9.alphaValues = cfg.deploy.alphaValues;
    q9.primaryAlpha = cfg.deploy.primaryAlpha;
end
if isfield(cfg, "analysis")
    q9.useOutlierFilter = cfg.analysis.useOutlierFilterPrimary;
end
if isfield(cfg, "parallel")
    q9.useParfor = cfg.parallel.enabled;
end

if isfield(cfg, "q9")
    src = cfg.q9;
    fields = fieldnames(q9);
    for i = 1:numel(fields)
        f = fields{i};
        if isfield(src, f)
            q9.(f) = src.(f);
        end
    end
    if isfield(src, "krVariant") && strlength(string(src.krVariant)) > 0
        q9.krVariant = char(string(src.krVariant));
    end
end

validateQ9MethodKeys(q9);

end

function validateQ9MethodKeys(q9)
methods = KrMethodRegistry();
lookupKrMethodRegistry(q9.lowMethodKey, methods);
lookupKrMethodRegistry(q9.highMethodKey, methods);
if ~isfinite(q9.switchForceN) || q9.switchForceN < 0
    error("resolveQ9Settings:BadSwitchForce", ...
        "cfg.q9.switchForceN は非負の有限値である必要があります。");
end

end
