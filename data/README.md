# Raw data layout

Place (or keep) the measurement files as follows. This folder is bundled in the
reproduction package (~630 MB total).

```
data/
  size_weight.xlsx     specimen size (L1, L2, h) and mass
  visco/  v###.CSV     viscoelastic (creep) waveforms
  yield/  y###.csv     compression / bioyield waveforms
```

Do not put derived MATLAB products here; they belong under `outputs/prepare/`.
