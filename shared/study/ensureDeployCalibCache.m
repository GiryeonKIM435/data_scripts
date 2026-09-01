function out = ensureDeployCalibCache(cfg, cohort, opts)
%ensureDeployCalibCache deploy_calib_chord.mat を構築また�E再利用

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, "analysisTag")
    opts.analysisTag = cohortCacheTag(cfg);
end
if ~isfield(opts, "forceRebuild")
    opts.forceRebuild = false;
end
if ~isfield(opts, "q1Results")
    opts.q1Results = [];
end

methodKeys = cfg.krMethodKeys(:);
nSamples = cohort.n;
calibFp = buildStudyCacheFingerprint(cfg, cohort, struct("kind", "deploy_calib"));
out = struct();
out.hit = false;
out.built = false;
out.source = "";
out.cachePath = "";

if ~opts.forceRebuild && cfg.cache.enabled
    loaded = loadDeployCalibCache(cfg, opts.analysisTag, calibFp, methodKeys, nSamples);
    if loaded.hit
        out.hit = true;
        out.source = "disk";
        out.cachePath = fullfile(resolveDeployCacheDir(cfg, opts.analysisTag), "deploy_calib_chord.mat");
        return;
    end
end

nM = numel(methodKeys);
deployCalibChord = cell(nM, 1);
fromQ1 = false(nM, 1);
source = "";

if ~isempty(opts.q1Results) && isfield(opts.q1Results, "methodKeys")
    q1Calib = extractQ1DeployCalib(opts.q1Results);
    if ~isempty(q1Calib)
        q1Keys = string(opts.q1Results.methodKeys(:));
        [deployCalibChord, fromQ1] = fillDeployCalibFromQ1(methodKeys, q1Keys, q1Calib);
        if all(fromQ1)
            source = "q1Results";
        end
    end
else
    q1Mat = fullfile(cfg.out.q1, opts.analysisTag, "kr_benchmark_results.mat");
    if isfile(q1Mat)
        sq1 = load(q1Mat, "results");
        if isfield(sq1.results, "methodKeys")
            q1Keys = string(sq1.results.methodKeys(:));
            q1Calib = extractQ1DeployCalib(sq1.results);
            [deployCalibChord, fromQ1] = fillDeployCalibFromQ1(methodKeys, q1Keys, q1Calib);
            if all(fromQ1)
                source = "q1_mat";
            end
        end
    end
end

nStale = 0;
for mi = 1:nM
    if ~fromQ1(mi)
        continue;
    end
    if isDeployCalibChordCompatible({deployCalibChord{mi}}, nSamples)
        continue;
    end
    warning("ensureDeployCalibCache:StaleMethodCalib", ...
        "方弁E%s の calib ぁEn=%d と不一致のため再計算します。", methodKeys(mi), nSamples);
    fromQ1(mi) = false;
    deployCalibChord{mi} = [];
    nStale = nStale + 1;
end
if nStale > 0 && strlength(source) > 0
    source = "";
end

if strlength(source) > 0 && ~isDeployCalibChordCompatible(deployCalibChord, nSamples)
    warning("ensureDeployCalibCache:StaleQ1Calib", ...
        "Q1 calib の試料数 (%d 想宁E が現在のコホ�EチEn=%d と不一致のため再計算します。", ...
        localCalibLength(deployCalibChord), nSamples);
    source = "";
    fromQ1 = false(nM, 1);
    deployCalibChord = cell(nM, 1);
end

if ~all(fromQ1)
  nMissing = nM - nnz(fromQ1);
  if nnz(fromQ1) > 0
      warning("ensureDeployCalibCache:PartialQ1Calib", ...
          "Q1 calib に %d/%d 方式がありません。不足刁E�� master から計算します。", ...
          nMissing, nM);
  else
      fprintf("beforeQ3 calib: %d 方式を master から計算中\n", nM);
  end
  missingIdx = find(~fromQ1);
  useParallel = false;
  if isfield(cfg, "parallel") && isfield(cfg.parallel, "parallelCalibBuild")
      useParallel = logical(cfg.parallel.parallelCalibBuild);
  end
  poolInfo = ensurePaperStudyParallelPool(cfg);
  useParallel = useParallel && poolInfo.active && numel(missingIdx) > 1;
  tCalib = tic;
  if useParallel
      pool = gcp("nocreate");
      tasks = repmat(struct("fn", [], "args", {{}}, "label", "", "nOut", 1), numel(missingIdx), 1);
      for ti = 1:numel(missingIdx)
          mi = missingIdx(ti);
          tasks(ti).fn = @computeDeployCalibForMethod;
          tasks(ti).args = {cfg, cohort, methodKeys(mi)};
          tasks(ti).label = char(methodKeys(mi));
          tasks(ti).nOut = 1;
      end
      calibResults = runParallelTaskBatch(pool, tasks, struct( ...
          "prefix", "beforeQ3 calib", ...
          "pollSeconds", 5, ...
          "tStart", tCalib));
      for ti = 1:numel(missingIdx)
          deployCalibChord{missingIdx(ti)} = calibResults{ti};
      end
  else
      logEvery = max(1, min(50, ceil(nMissing / 10)));
      computed = 0;
      for ti = 1:numel(missingIdx)
          mi = missingIdx(ti);
          deployCalibChord{mi} = computeDeployCalibForMethod(cfg, cohort, methodKeys(mi));
          computed = computed + 1;
          if computed == nMissing || mod(computed, logEvery) == 0
              fprintf("beforeQ3 calib: %d/%d 方式（新規計箁E%d/%d�E�\n", mi, nM, computed, nMissing);
          end
      end
  end
  if nnz(fromQ1) > 0
      source = "q1_partial+master";
  else
      source = "computed";
  end
end

if cfg.cache.enabled
    out.cachePath = saveDeployCalibCache(cfg, opts.analysisTag, methodKeys, deployCalibChord, calibFp);
end

out.hit = true;
out.built = true;
out.source = source;
out.methodKeys = methodKeys;
out.deployCalibChord = deployCalibChord;
out.deployCalib = deployCalibChord;

end

function [deployCalibChord, fromQ1] = fillDeployCalibFromQ1(methodKeys, q1Keys, q1CalibCell)
nM = numel(methodKeys);
deployCalibChord = cell(nM, 1);
fromQ1 = false(nM, 1);
for mi = 1:nM
    idx = find(q1Keys == methodKeys(mi), 1);
    if isempty(idx)
        continue;
    end
    deployCalibChord{mi} = q1CalibCell{idx};
    fromQ1(mi) = true;
end
end

function tag = cohortCacheTag(cfg)
if isfield(cfg, "cache") && isfield(cfg.cache, "cohortAnalysisTag")
    tag = char(cfg.cache.cohortAnalysisTag);
else
    tag = "burgers_iqr2";
end

end

function n = localCalibLength(deployCalibChord)
n = nan;
for i = 1:numel(deployCalibChord)
    c = deployCalibChord{i};
    if isstruct(c) && isfield(c, "a")
        n = numel(c.a(:));
        return;
    end
end

end
