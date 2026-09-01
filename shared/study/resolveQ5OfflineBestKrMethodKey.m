function [key, source] = resolveQ5OfflineBestKrMethodKey(cfg, opts)
%resolveQ5OfflineBestKrMethodKey Q5 offline 比較用の Q1 最良 kr 方式

if nargin < 2
    opts = struct();
end

if isfield(cfg, "q5") && isfield(cfg.q5, "offlineBestKrMethodKey") ...
        && strlength(string(cfg.q5.offlineBestKrMethodKey)) > 0
    key = string(cfg.q5.offlineBestKrMethodKey);
    source = "cfg.q5.offlineBestKrMethodKey";
    return;
end

if nargin >= 2 && isfield(opts, "offlineBestKrMethodKey") ...
        && strlength(string(opts.offlineBestKrMethodKey)) > 0
    key = string(opts.offlineBestKrMethodKey);
    source = "opts.offlineBestKrMethodKey";
    return;
end

q1Summary = loadQ1SummaryTable(cfg);
key = string(resolveQ1BestMethodKey(q1Summary, cfg));
if strlength(key) == 0
    key = "ftrail_f30_w30";
    source = "default_ftrail_f30_w30";
else
    source = "Q1 overall best";
end

end
