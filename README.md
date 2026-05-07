# Skull Properties Analysis

This folder contains a cleaned user-facing wrapper around the original MATLAB
research code for skull CT property analysis.

## What This Runs

```text
skull CT volume
  -> target detection
  -> seed ray generation
  -> direct ray sampling
  -> skull thickness / SDR / HU / density / speed analysis
  -> skull surface property table
```

Transmission calculation is intentionally excluded from the main workflow.

## Quick Start

```matlab
cd('C:\Users\Labuser\Documents\Skull_analyse_project')
result = run_skull_properties_analysis();
```

By default, this loads `skull_v_resized_generate_face.mat`, detects the
`6000`-valued target marker, grows seed locations, traces seed-to-target skull
paths, and estimates skull properties.

## Example: Fast Trial

```matlab
cd('C:\Users\Labuser\Documents\Skull_analyse_project')

result = run_skull_properties_analysis('skull_v_resized_generate_face.mat', ...
    'SeedCount', 2000);
```

## Example: Full Properties Run

```matlab
cd('C:\Users\Labuser\Documents\Skull_analyse_project')

result = run_skull_properties_analysis('skull_v_resized_generate_face.mat', ...
    'SeedCount', 400000, ...
    'SaveOutput', true);
```

Saved output is written to:

```text
results_properties/<timestamp>/skull_properties_result.mat
```

## Example: Custom Target

Use this when the target is not already marked by `6000` voxels.

```matlab
target = [219 139 200];  % [row column slice]

result = run_skull_properties_analysis('skull_v_resized_generate_face.mat', ...
    'BrainTarget', target, ...
    'SeedCount', 400000, ...
    'SaveOutput', true);
```

## Example: Raw CT Input

Use `ApplySkullExtraction=true` only when the input is raw/preprocessed CT and
still needs skull extraction.

```matlab
result = run_skull_properties_analysis('my_ct_volume.mat', ...
    'InputVariable', 'ct_data', ...
    'BrainTarget', [219 139 200], ...
    'ApplySkullExtraction', true, ...
    'SeedCount', 400000);
```

## Useful Options

- `SeedCount`: number of requested seed directions before de-duplication.
- `BrainTarget`: `[row column slice]` target coordinate. If omitted, the wrapper
  detects the center of voxels with value `6000`.
- `ApplySkullExtraction`: set `true` when the input is raw/preprocessed CT and
  still needs `generate_skull_volume`.
- `AngleMethod`: `'default'` for speed, or `'pca'` for local PCA angle estimates.
- `SaveOutput`: save `result` to
  `results_properties/<timestamp>/skull_properties_result.mat`.

## Result Structure

```matlab
result.summary          % high-level run information
result.geometry         % target, seed coordinates, and coordinate mapping
result.surface.table    % one row per accepted skull surface point
result.properties       % arrays of thickness, SDR, HU, density, speed, angles
```

The most useful table for users is:

```matlab
T = result.surface.table;
head(T)
```

Important columns include:

```text
X, Y, Z                 skull surface point in expanded seed coordinates
VolumeRow              row in the original CT volume
VolumeColumn           column in the original CT volume
VolumeSlice            slice in the original CT volume
ThicknessVoxels         skull thickness in voxels
ThicknessMm             skull thickness in millimeters
DensityRatio            SDR / density ratio
MeanHU                  mean Hounsfield value along skull path
OuterAngleDeg           outer skull insertion angle
InnerAngleDeg           inner skull insertion angle
OuterDensity            outer cortical density
TrabecularDensity       trabecular density
InnerDensity            inner cortical density
OuterSpeed              outer cortical sound speed
TrabecularSpeed         trabecular sound speed
InnerSpeed              inner cortical sound speed
```

The separate file `run_skull_analysis_clean.m` keeps the experimental
transmission calculation for later use, but new users should start with the
properties-only function above.

## Plotting

```matlab
plot_skull_analysis_result(result, 'Metric', 'thickness');
plot_skull_analysis_result(result, 'Metric', 'densityRatio');
```

Available plotting metrics:

```text
thickness
densityRatio
hu
angle
```

## Export Table

```matlab
writetable(result.surface.table, 'skull_properties_table.csv');
```

## Original Computational Kernels

The properties-only wrapper uses or preserves the original model functions,
including:

- `calculate_skull_propeties`
- `generate_skull_volume`
- `hounsfield2density` from k-Wave

The old exploratory scripts are still present for reference, but new users
should start with `run_skull_properties_analysis`.
