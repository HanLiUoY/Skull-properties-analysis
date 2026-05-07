# GitHub Upload Checklist

## Upload These Files

Core user-facing workflow:

```text
README.md
.gitignore
run_skull_properties_analysis.m
create_demo_skull_volume.m
example_run_without_large_data.m
example_run_skull_properties_analysis.m
plot_skull_analysis_result.m
calculate_skull_propeties.m
generate_skull_volume.m
```

Optional legacy/transmission files, only if you want to share the old research
workflow as reference:

```text
run_skull_analysis_clean.m
run_skull_analysis.m
full_skull_properties_analysis.m
full_skull_tra_ref_coef.m
calculate_tra_ref_coef.m
calculate_tran_skull_info.m
w_s_interface.m
s_w_interface.m
s_s_interface.m
calculate_insertion_angle.m
calculate_skull2center.m
ct_data_transformation.m
filter_duplicate_signal.m
find_seed2center.m
find_seed2center_trim.m
generate_insertion_line.m
generate_trans_skull.m
grow_seeds_around_skull.m
grow_seeds_around_target.m
identify_brain_target.m
plant_seed_data2skull.m
```

## Do Not Upload These Files

These are local/generated or too large for a normal GitHub repository:

```text
*.mat
*.nii
*.nii.gz
demo_skull_volume.mat
skull.mat
skull_volume.mat
skull_v_resized_generate_face.mat
results/
results_clean/
results_properties/
```

The demo `.mat` file is generated locally by:

```matlab
create_demo_skull_volume();
```

## Public Demo Name

The GitHub-facing demo file name is:

```text
demo_skull_volume.mat
```

The variable saved inside it is:

```text
demo_skull_volume
```

The old private/example names such as `skull_v_resized_generate_face.mat`,
`skull.mat`, and `skull_volume.mat` should not be used in the public README.

## External Dependency

`calculate_skull_propeties.m` calls `hounsfield2density`, which is commonly
provided by k-Wave. Users need k-Wave or an equivalent `hounsfield2density`
function on the MATLAB path.
