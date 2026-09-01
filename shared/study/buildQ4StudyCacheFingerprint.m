function fp = buildQ4StudyCacheFingerprint(cfg, cohort, opts)
%buildQ4StudyCacheFingerprint Q4 キャッシュの整合性キー

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "kind")
    opts.kind = "q4";
end

parts = strings(0, 1);
parts(end + 1, 1) = "kind=" + string(opts.kind);
parts(end + 1, 1) = "ids=" + join(string(cohort.ids(:)'), ",");
parts(end + 1, 1) = "oof=" + string(logical(cohort.useOutlierFilter));
parts(end + 1, 1) = "methodKey=" + string(cfg.q4.methodKey);
parts(end + 1, 1) = "offlineStart=" + string(cfg.q4.offlineBandStartSec);
parts(end + 1, 1) = "offlineWidth=" + string(cfg.q4.offlineBandWidthSec);
parts(end + 1, 1) = "onlineWindow=" + string(cfg.q4.onlineWindowSec);
parts(end + 1, 1) = "krVariant=" + string(cfg.q4.krVariant);
parts(end + 1, 1) = "timeOrder=" + string(cfg.deploy.timeOrder);
parts(end + 1, 1) = "krContact=" + string(krContactConfigFingerprint());

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

fp = struct();
fp.key = char(join(parts, "|"));
fp.hash = simpleFingerprintHash(fp.key);
fp.createdAt = datetime("now");
fp.kind = char(opts.kind);

end

function h = simpleFingerprintHash(key)
bytes = uint8(key);
acc = uint64(0);
for i = 1:numel(bytes)
    acc = acc + uint64(bytes(i)) * uint64(131);
    acc = bitand(acc, uint64(4294967295));
end
h = sprintf("%08x", acc);
end
