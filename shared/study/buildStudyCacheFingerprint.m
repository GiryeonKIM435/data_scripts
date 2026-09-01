function fp = buildStudyCacheFingerprint(cfg, cohort, opts)
%buildStudyCacheFingerprint 共有キャッシュの整合性キーを構築

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "kind")
    opts.kind = "deploy";
end

pipelineCfg = PipelineConfig();
zeroAdj = getZeroAdjustEnabled(pipelineCfg);

parts = strings(0, 1);
parts(end + 1, 1) = "kind=" + string(opts.kind);
parts(end + 1, 1) = "ids=" + join(string(cohort.ids(:)'), ",");
parts(end + 1, 1) = "oof=" + string(logical(cohort.useOutlierFilter));
parts(end + 1, 1) = "timeOrder=" + string(cfg.deploy.timeOrder);
parts(end + 1, 1) = "krVariant=" + string(cfg.deploy.krVariant);
parts(end + 1, 1) = "zeroAdj=" + string(logical(zeroAdj));
parts(end + 1, 1) = "krContact=" + string(krContactConfigFingerprint());
parts(end + 1, 1) = "deployBranch=extractLoadingBranchToYield";
parts(end + 1, 1) = "deployYieldBand=causal_cohort_ymin";
parts(end + 1, 1) = "streamRefit=pct_everyStep_gtN";
if isfield(cfg, "deploy") && isfield(cfg.deploy, "minBandPointsForKr")
    parts(end + 1, 1) = "minBandPointsForKr=" + string(cfg.deploy.minBandPointsForKr);
end
if isfield(cfg, "deploy") && isfield(cfg.deploy, "percentYieldBandGatePoints")
    parts(end + 1, 1) = "percentYieldBandGatePoints=" + string(cfg.deploy.percentYieldBandGatePoints);
end
if isfield(cfg, "krMethodKeys") && ~isempty(cfg.krMethodKeys)
    parts(end + 1, 1) = "nKrMethods=" + string(numel(cfg.krMethodKeys));
    parts(end + 1, 1) = "krMethodsHash=" + string(simpleFingerprintHash(join(string(cfg.krMethodKeys(:)), ",")));
end
pathFields = ["masterTable", "cohortManifest", "tomatoDataset"];
for pi = 1:numel(pathFields)
    p = pathFields(pi);
    f = string(cfg.paths.(p));
    parts(end + 1, 1) = p + "=" + f;
    if isfile(f)
        d = dir(char(f));
        parts(end + 1, 1) = p + "_mtime=" + string(d.datenum);
    end
end

if isfield(opts, "methodKey") && strlength(string(opts.methodKey)) > 0
    parts(end + 1, 1) = "methodKey=" + string(opts.methodKey);
end

fp = struct();
fp.key = char(join(parts, "|"));
fp.hash = simpleFingerprintHash(fp.key);
fp.createdAt = datetime("now");
fp.kind = char(opts.kind);

end

function h = simpleFingerprintHash(key)
key = char(string(key));
bytes = uint8(key);
acc = uint64(0);
for i = 1:numel(bytes)
    acc = acc + uint64(bytes(i)) * uint64(131);
    acc = bitand(acc, uint64(4294967295));
end
h = sprintf("%08x", acc);

end
