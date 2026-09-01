function fp = buildQ6SlopeCacheFingerprint(cfg, cohort, sampleCtxFp)
%buildQ6SlopeCacheFingerprint Q6 傾きプロファイルキャッシュの指紋

parts = strings(0, 1);
parts(end + 1, 1) = "kind=q6_slope";
parts(end + 1, 1) = "deployCtxHash=" + string(sampleCtxFp.hash);
parts(end + 1, 1) = "ids=" + join(string(cohort.ids(:)'), ",");
parts(end + 1, 1) = "oof=" + string(logical(cohort.useOutlierFilter));

if isfield(cfg, "q6")
    q6 = cfg.q6;
    if isfield(q6, "forceGridMode")
        parts(end + 1, 1) = "forceGridMode=" + string(q6.forceGridMode);
    end
    if isfield(q6, "nForceGrid")
        parts(end + 1, 1) = "nForceGrid=" + string(q6.nForceGrid);
    end
    if isfield(q6, "yieldPctGridStep")
        parts(end + 1, 1) = "yieldPctGridStep=" + string(q6.yieldPctGridStep);
    end
    if isfield(q6, "minDefStepMm")
        parts(end + 1, 1) = "minDefStepMm=" + string(q6.minDefStepMm);
    end
    if isfield(q6, "binnedForceWidthsN")
        parts(end + 1, 1) = "binnedW=" + join(string(q6.binnedForceWidthsN(:)'), ",");
    end
    if isfield(q6, "binnedMinPoints")
        parts(end + 1, 1) = "binnedMinPts=" + string(q6.binnedMinPoints);
    end
end

fp = struct();
fp.key = char(join(parts, "|"));
fp.hash = simpleFingerprintHash(fp.key);
fp.createdAt = datetime("now");
fp.kind = "q6_slope";

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
