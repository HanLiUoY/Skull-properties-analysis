% Example: run skull-properties-only analysis.
%
% This example does not calculate acoustic transmission. It estimates skull
% surface points, thickness, SDR/density ratio, HU, layer density, layer speed,
% and insertion angles.

projectRoot = fileparts(mfilename('fullpath'));
inputFile = fullfile(projectRoot, 'demo_skull_volume.mat');

if ~isfile(inputFile)
    create_demo_skull_volume('OutputFile', inputFile);
end

result = run_skull_properties_analysis(inputFile, ...
    'SeedCount', 2000, ...
    'SaveOutput', true);

plot_skull_analysis_result(result, 'Metric', 'thickness');
plot_skull_analysis_result(result, 'Metric', 'densityRatio');
