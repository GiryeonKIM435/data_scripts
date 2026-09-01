function setup_paths()
%setup_paths Add tomato_yield_paper_repro folders to the MATLAB path
%
% Uses repository-relative paths only (no absolute / external deps).

repoRoot = fileparts(mfilename("fullpath"));

addpath(repoRoot);
addpath(fullfile(repoRoot, "config"));

% Paper study helpers (shared/study) before pipeline utilities
addpath(fullfile(repoRoot, "shared", "study"));
addpath(fullfile(repoRoot, "shared", "analyze_shared"));
addpath(fullfile(repoRoot, "shared", "pipeline_utils"));
addpath(fullfile(repoRoot, "shared", "pipeline_utils", "io"));
addpath(fullfile(repoRoot, "shared", "pipeline_utils", "yield"));
addpath(fullfile(repoRoot, "shared", "pipeline_utils", "burgers"));
addpath(fullfile(repoRoot, "shared", "pipeline_utils", "kr"));
addpath(fullfile(repoRoot, "shared", "pipeline_utils", "waveform"));
addpath(fullfile(repoRoot, "shared", "pipeline_utils", "estimate"));
addpath(fullfile(repoRoot, "shared", "pipeline_utils", "preprocess"));
addpath(fullfile(repoRoot, "shared", "pipeline_utils", "plotting"));

addpath(fullfile(repoRoot, "s1_prepare", "01_load"));
addpath(fullfile(repoRoot, "s1_prepare", "02_estimate"));
addpath(fullfile(repoRoot, "s1_prepare", "03_preprocess"));
addpath(fullfile(repoRoot, "s2_offline"));
addpath(fullfile(repoRoot, "s3_online"));
addpath(fullfile(repoRoot, "s4_contribution"));
addpath(fullfile(repoRoot, "s5_report"));

end
