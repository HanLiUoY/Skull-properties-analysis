% Example: run the skull-properties pipeline without committing a CT file.
%
% This creates a small synthetic skull-like volume locally, then runs the
% properties analysis. The synthetic volume is only for code demonstration.

cd(fileparts(mfilename('fullpath')));

create_demo_skull_volume();

result = run_skull_properties_analysis('demo_skull_volume.mat', ...
    'SeedCount', 2000, ...
    'SaveOutput', false);

disp(result.summary)
head(result.surface.table)

plot_skull_analysis_result(result, 'Metric', 'thickness');
