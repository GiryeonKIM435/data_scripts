# Glossary: paper terms and internal identifiers

Public names follow the manuscript English. Some internal function names
keep historical identifiers (e.g. `fitBurgersBatch`); manuscript cohort
files and output tags use Jeffreys naming.

## RUN__paper flags

| Flag | Role |
|------|------|
| `doLoad` / `doEstimate` / `doPreprocess` | Prepare |
| `doDescriptive` | Results 4.1 |
| `doPostTest` | Results 4.2 |
| `doSequentialReplay` | Results 4.3 |
| `doAdditionalPredictors` | Results 4.4 |
| `doFigTable` | Paper figures/tables |
| `reuseExistingResults` | Reuse existing 4.2/4.3 `.mat` when present |
| `skipIfExists` | Skip prepare products that already exist |
| `forceRecompute` | Force prepare recompute (overrides skip) |
| `primaryAnalysisTag` | Output/cache folder tag (default `jeffreys_bi_iqr15`) |
| `useShippedJeffreysCohort` | `true`: load shipped IQR mats (paper numbers); `false`: allow stochastic re-fit |
| `doSensitivityNoIqr` | Sensitivity: Jeffreys IQR reject off |
| `doSensitivityInclVisual` | Sensitivity: primary complete + visual IDs 8, 71 (no re-IQR; target n=89) |
| `doSensitivityKrLs` | Sensitivity: same cohort; stiffness \(k\) via LS (`sens_kr_ls`) |
| `doSensitivityHarvestDay` | Sensitivity: harvest-day subsets (4/23 and 4/29) |
| `doSensitivitySummary` | Write `sensitivity_vs_primary.csv` |

## Evaluation stages

| Paper term | Prefer | Legacy path / folder |
|------------|--------|----------------------|
| post-test evaluation | `doPostTest` | `s2_offline` |
| sequential replay | `doSequentialReplay` | `s3_online` |
| additional predictors | `doAdditionalPredictors` | `s4_contribution` |
| design \(\alpha_{0.95}^{(-i)}\) | — | `designAlpha` in code |

## Mechanical / model quantities

| Paper term | Prefer | Code / cache note |
|------------|--------|-------------------|
| mechanical bioyield force \(F_\mathrm{Y}\) | `F_Y` | `yieldPointN` |
| apparent compression stiffness \(k\) | stiffness / \(k\) | `kr`, `krMethodKey` |
| absolute-force intervals | — | `force_abs`, `force_s##_w##` |
| Jeffreys model | Jeffreys | params `k2`/\(k_\mathrm{K}\), `c1`/\(c_\mathrm{M}\), `c2`/\(c_\mathrm{K}\) |
| equivalent diameter | `d_eq` | — |
| cohort cache tag | — | `primaryAnalysisTag` (default `jeffreys_bi_iqr15`) |

## Safety labels

| Paper | Prefer | Code |
|-------|--------|------|
| failure (reached measured \(F_\mathrm{Y}\)) | `bioyield` | `fail`, `nSafeStopFail` |
| premature protective stop | `premature` | `early`, `nEarlyStop` |

## Entry wrappers

| Paper-facing | Implementation |
|--------------|----------------|
| `run_fit_jeffreys_visco` | Jeffreys creep identification |
| `run_prepare_jeffreys_bi_iqr15` | Optional regenerator for manuscript IQR cohort mats |
| `run_prepare_jeffreys_no_iqr` | Sensitivity prepare: IQR reject off |
| `run_prepare_jeffreys_incl_visual` | Sensitivity prepare: include IDs 8, 71 |
| `run_prepare_jeffreys_harvest_day_subset` | Sensitivity prepare: harvest-day cohort mask |
| `run_sensitivity_checks_summary` | Primary vs single-factor sensitivity table |
| `run_jeffreys_fit_audit` | Methods Jeffreys fit audit |
| `run_paper_fig_table` | Methods audits + Results figures + assemble |

Note: `runNestedLoocvModels` is the multi-model LOOCV helper for Results 4.4.
