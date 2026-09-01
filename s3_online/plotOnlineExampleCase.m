function outPath = plotOnlineExampleCase(cfg, cohort, methodKey, alphaDesign, outDir, sampleId, opts)
%plotOnlineExampleCase 結果4.3: オンライン推定過程の一例図（論文スタイル）
%
% 黒実線 F(t)、黒破線 F_yield、水色帯（剛性推定力区間）、
% 赤実線 ŷ(t)、赤破線 ŷ/α、紫破線 停止時刻。
%
% opts.fileTag   : 出力ファイルタグ（既定 "example"）
%                  → fig4_3_online_<fileTag>_<method>_idXXX.png
% opts.titleNote : タイトル末尾注記（例: "fail_never_stopped"）
% opts.usePaperStyle : true（既定）で論文色分け。false で旧 multi-α 図

if nargin < 6 || isempty(sampleId)
    sampleId = cfg.paper.exampleSampleId;
end
if nargin < 7 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "fileTag") || strlength(string(opts.fileTag)) == 0
    opts.fileTag = "example";
end
if ~isfield(opts, "titleNote")
    opts.titleNote = "";
end
if ~isfield(opts, "usePaperStyle")
    opts.usePaperStyle = true;
end
if ~isfolder(outDir)
    mkdir(outDir);
end

idx = find(cohort.ids == sampleId, 1);
if isempty(idx)
    warning("plotOnlineExampleCase:MissingSample", ...
        "exampleSampleId=%d がコホートにありません。先頭試料を使用します。", sampleId);
    idx = 1;
    sampleId = cohort.ids(1);
end

methods = KrMethodRegistry();
mdef = lookupKrMethodRegistry(methodKey, methods);
[sampleCtx, fitCfg, ~] = loadQ4DeploySampleCtx(cfg, cohort);
ctx = sampleCtx{idx};
yTrue = cohort.y(idx);
calib = resolveDeployCalibForPaperFigure(cfg, cohort, methodKey);

sampleOpts = struct();
sampleOpts.krVariant = char(string(cfg.deploy.krVariant));
policy = resolveStreamDeployPolicy(sampleOpts, cfg);
sampleOpts.minBandPointsForKr = policy.minBandPointsForKr;
sampleOpts.percentYieldBandGatePoints = policy.percentYieldBandGatePoints;
if string(mdef.type) == "percent_yield"
    sampleOpts.calibA = calib.a(idx);
    sampleOpts.calibB = calib.b(idx);
    sampleOpts.yminCohortAbs = computeCohortYieldMin(cohort.y);
end

krPath = streamDeployKrPath(ctx, yTrue, mdef, fitCfg, sampleOpts);
traj = applyDeployCalibToTrajectory(krPath, yTrue, calib.a(idx), calib.b(idx));

outcome = evalStopAlphas(traj, alphaDesign, yTrue);
tStop = outcome.t_stop;

if opts.usePaperStyle && string(opts.fileTag) == "example" ...
        && ~logical(outcome.isSafeStop)
    warning("plotOnlineExampleCase:NotSafeStopSuccess", ...
        ["論文例示は安全停止成功を想定していますが、id=%d / %s / alpha=%.3f の " ...
        "outcome=%s です。図は出力します。"], ...
        sampleId, char(string(methodKey)), alphaDesign, char(string(outcome.outcome)));
end
fprintf("4.3 online example plot: id=%d method=%s alpha=%.3f outcome=%s F_stop=%.2f\n", ...
    sampleId, char(string(methodKey)), alphaDesign, char(string(outcome.outcome)), ...
    outcome.F_stop);

forceOffsetN = 0;
if isfield(ctx, "forceOffsetN") && isfinite(ctx.forceOffsetN)
    forceOffsetN = ctx.forceOffsetN;
end
if isfield(traj, "forceAbs")
    forceAbs = traj.forceAbs(:);
else
    forceAbs = traj.force(:) + forceOffsetN;
end

slug = char(strrep(string(methodKey), " ", "_"));
fileTag = char(string(opts.fileTag));
outPath = fullfile(outDir, sprintf("fig4_3_online_%s_%s_id%03d.png", fileTag, slug, sampleId));

forceLowN = nan;
forceHighN = nan;
if isfield(mdef, "lowN") && isfield(mdef, "highN") ...
        && isfinite(mdef.lowN) && isfinite(mdef.highN)
    forceLowN = mdef.lowN;
    forceHighN = mdef.highN;
end

if string(opts.fileTag) == "example" && strlength(string(opts.titleNote)) == 0
    if opts.usePaperStyle
        titleStr = "";
    else
        titleStr = sprintf("Online estimation example (id=%d, %s, alpha_0.95=%.3f)", ...
            sampleId, mdef.label, alphaDesign);
    end
else
    titleStr = sprintf("Online estimation (id=%d, %s, alpha_0.95=%.3f)", ...
        sampleId, mdef.label, alphaDesign);
end
if strlength(string(opts.titleNote)) > 0
    titleStr = sprintf("%s, %s", titleStr, char(string(opts.titleNote)));
end

if opts.usePaperStyle
    plotOnlinePaperExampleFigure(ctx.sec(:), forceAbs, yTrue, traj.yHat(:), ...
        alphaDesign, tStop, forceLowN, forceHighN, titleStr, outPath, cfg);
else
    plotQ3DeployForceTimeMultiAlphaFigure(ctx.sec(:), forceAbs, yTrue, traj.yHat(:), ...
        alphaDesign, tStop, titleStr, outPath, cfg);
end

end
