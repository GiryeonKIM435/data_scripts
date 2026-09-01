# tomato_yield_paper_repro

Self-contained MATLAB package to reproduce the main analyses of the tomato
mechanical bioyield force prediction manuscript (Agriculture). This is a
**public** repository: raw measurement data (about 630 MB under `data/`) and
the shipped Jeffreys IQR cohort mats (see below) are included so reviewers can
reproduce the manuscript numbers without re-running stochastic fits. Large
`outputs/` analysis caches are excluded and regenerated locally.

See [GLOSSARY.md](GLOSSARY.md) for manuscript English versus internal code names.

## Authors and affiliation

- Giryeon Kim, Kenichi Tokuda, Ryo Arai, and Wataru Iizima
- Research Center for Agricultural Robotics,
  National Agriculture and Food Research Organization (NARO),
  1-31-1 Kannondai, Tsukuba, Ibaraki 305-0856, Japan
- Correspondence: kim.giryeon435@naro.go.jp

## Acknowledgments

This public GitHub package was reorganized from the original MATLAB scripts and
data used for the manuscript analyses. Repository layout, documentation, and
packaging for release were prepared with AI coding-tool assistance (Cursor).
The scientific methods, measurements, and analyses were developed and verified
by the manuscript authors.

## Requirements

- MATLAB R2024a or later (developed/tested on R2025b)
- Statistics and Machine Learning Toolbox; Optimization Toolbox
- Optional: Parallel Computing Toolbox

## How to run

Edit flags at the top of `RUN__paper.m`.

| Flag | Role |
|------|------|
| `doLoad` / `doEstimate` / `doPreprocess` | Prepare (raw to cohort) |
| `doDescriptive` | Results 4.1 |
| `doPostTest` | Results 4.2 post-test LOOCV |
| `doSequentialReplay` | Results 4.3 sequential replay |
| `doAdditionalPredictors` | Results 4.4 additional predictors |
| `doFigTable` | Paper figures and tables from available products |

Suggested order: Load → Estimate → Preprocess → 4.1 → 4.2 → 4.3 → 4.4 → FigTable.

`doFigTable` may be run whenever inputs exist; missing stages are skipped.

### Analysis settings

Edit these in `RUN__paper.m`:

| Setting | Paper-matching default | Role |
|---------|------------------------|------|
| `primaryAnalysisTag` | `"jeffreys_bi_iqr15"` | Output/cache folder name under `sec4_*` / `shared_cache` |
| `useShippedJeffreysCohort` | `true` | Load shipped Jeffreys IQR mats (see below) |

- Apparent stiffness \(k\): chord estimator on absolute-force intervals
- Viscoelastic model: Jeffreys
- Chord variant: `chord`

### Jeffreys fit randomness and manuscript numbers

Jeffreys creep identification uses multi-start optimization with random
initial jitter (`fitRngSeed` plus per-fruit ID in the fitter). **Re-running**
`run_prepare_jeffreys_bi_iqr15` can change which samples pass the bilateral-IQR
gate, change the complete-set size, and therefore change LOOCV / deploy metrics
relative to the manuscript.

**Do not regenerate the primary cohort for paper reproduction.** This
repository ships the manuscript-frozen products under `outputs/prepare/` (four
`.mat` files below). Keep `useShippedJeffreysCohort = true` so `RUN__paper.m`
loads those files instead of re-fitting.

**To reproduce the manuscript numbers**, keep:

```matlab
primaryAnalysisTag = "jeffreys_bi_iqr15";
useShippedJeffreysCohort = true;
```

That loads the shipped products under `outputs/prepare/`:

- `tomato_with_fit_bi_iqr15.mat`
- `jeffreys_fit_results_bi_iqr15.mat`
- `master_analysis_table_bi_iqr15.mat`
- `cohort_manifest_bi_iqr15.mat`

Set `useShippedJeffreysCohort = false` only if you intentionally want to
re-fit (`run_prepare_jeffreys_bi_iqr15`); expect numeric drift. You may
also change `primaryAnalysisTag` to write alternate runs into a separate
output folder without overwriting an existing paper-tagged result set.

### Single-factor sensitivity checks

Optional flags in `RUN__paper.m` re-run post-test / sequential / additional-predictor
analyses under **one changed factor at a time** (no combinatorial grid), then
compare min-MAE conditions and complementary \(\Delta\)MAE to the manuscript
primary (`jeffreys_bi_iqr15`):

| Flag | Factor changed |
|------|----------------|
| `doSensitivityNoIqr` | Jeffreys bilateral-IQR reject off |
| `doSensitivityInclVisual` | Append visual-excluded IDs 8 and 71 to primary complete (no re-IQR; target n=89) |
| `doSensitivityKrLs` | Same primary cohort; stiffness \(k\) via LS instead of chord |
| `doSensitivityHarvestDay` | Restrict cohort to 2026-04-23 only, then 2026-04-29 only |
| `doSensitivitySummary` | Write `outputs/sec4_sensitivity/sensitivity_vs_primary.csv` |

Harvest-day assignment follows raw visco timestamps: **id ≤ 50 → 2026-04-23**,
else → 2026-04-29 (`PaperStudyConfig.harvestBatchAMaxId`).

IQR-off and visual-include prepares write separate mats and do **not** overwrite
shipped `*_bi_iqr15.mat`. Re-fitting IQR-off is stochastic (see above).
`sens_incl_visual` freezes the primary IQR complete set and force-appends IDs 8/71
only (`rejectParamOutliers=false` for those two); if older products were built with
batch re-IQR (complete n≈86), regenerate with `forceRecompute=true`.
`sens_kr_ls` needs no prepare; it reuses primary mats with `krVariant="ls"`.

## Layout

```
tomato_yield_paper_repro/
  RUN__paper.m
  setup_paths.m
  GLOSSARY.md
  config/  s1_prepare/  s2_offline/  s3_online/  s4_contribution/  s5_report/
  shared/  data/
```

`outputs/` is mostly gitignored (created at runtime). The manuscript
Jeffreys IQR cohort mats under `outputs/prepare/` are shipped and tracked.

## Paper figure mapping (after doFigTable)

| Role | Assembled file under `paper_figures/` |
|------|----------------------------------------|
| Heatmap (a) post-test MAE±SEM/R² | `fig_res_heatmap_posttest_mae_r2_force_abs.png` |
| Heatmap (b) sequential MAE+bioyield+premature | `fig_res_heatmap_sequential_mae_bioyield_premature_force_abs.png` |
| Sequential example | `fig_res_sequential_example_*.png` |
| Spearman matrix | `fig_res_spearman_corr_matrix.png` |
| 4.4 post-test LOOCV scatter | `fig_res_q5_offline_loocv_scatter.png` |
| Bioyield / Jeffreys Methods | `fig_methods_bioyield_examples.png`, `fig_methods_jeffreys_fit_examples.png` |

See `outputs/paper_outputs_manifest.csv` for the full list.

## Citation

Please cite the associated Agriculture manuscript (Kim, Tokuda, Arai, and Iizima)
when using this software or data.

Repository: https://github.com/GiryeonKIM435/data_scripts

DOI will be added after journal publication.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
Copyright 2026 Giryeon Kim, Research Center for Agricultural Robotics, NARO.
See also [NOTICE](NOTICE).
