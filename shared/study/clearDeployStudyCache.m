function report = clearDeployStudyCache(cfg, opts)
%clearDeployStudyCache Q3 共有キャッシュ（sampleCtx / traj）を削除

if nargin < 1 || isempty(cfg)
    cfg = ensurePipelineReady();
end
if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "analysisTag")
    opts.analysisTag = cohortCacheTag(cfg);
end
if ~isfield(opts, "clearTraj")
    opts.clearTraj = true;
end
if ~isfield(opts, "clearSampleCtx")
    opts.clearSampleCtx = true;
end

cacheDir = resolveDeployCacheDir(cfg, opts.analysisTag);
report = struct();
report.cacheDir = cacheDir;
report.removedSampleCtx = false;
report.removedTrajFiles = 0;

if opts.clearSampleCtx
    ctxPath = fullfile(cacheDir, "deploy_sample_contexts.mat");
    if isfile(ctxPath)
        delete(ctxPath);
        report.removedSampleCtx = true;
    end
end

if opts.clearTraj
    trajDir = fullfile(cacheDir, "traj");
    if isfolder(trajDir)
        listing = dir(fullfile(trajDir, "*.mat"));
        for i = 1:numel(listing)
            delete(fullfile(listing(i).folder, listing(i).name));
            report.removedTrajFiles = report.removedTrajFiles + 1;
        end
    end
end

fprintf("clearDeployStudyCache [%s]: sampleCtx=%d, traj=%d files\n", ...
    opts.analysisTag, report.removedSampleCtx, report.removedTrajFiles);

end
