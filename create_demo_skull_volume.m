function [skullVolume, info] = create_demo_skull_volume(varargin)
%CREATE_DEMO_SKULL_VOLUME Generate a small synthetic skull-like demo volume.
%
% This function lets GitHub users run the skull-properties pipeline without
% downloading a large CT file. The generated volume is not patient data and is
% not intended for scientific validation; it is only a lightweight smoke-test
% dataset for demonstrating code usage.
%
% Example:
%   create_demo_skull_volume();
%   result = run_skull_properties_analysis('demo_skull_volume.mat', ...
%       'SeedCount', 2000);

opts = parseDemoOptions(varargin{:});

[rowGrid, colGrid, sliceGrid] = ndgrid( ...
    1:opts.VolumeSize(1), ...
    1:opts.VolumeSize(2), ...
    1:opts.VolumeSize(3));

target = opts.Target;

% Ellipsoidal radius centered on the target. A mild column/slice asymmetry
% makes the synthetic skull less perfectly spherical.
r = sqrt( ...
    ((rowGrid - target(1)) ./ opts.RowRadiusScale) .^ 2 + ...
    ((colGrid - target(2)) ./ opts.ColumnRadiusScale) .^ 2 + ...
    ((sliceGrid - target(3)) ./ opts.SliceRadiusScale) .^ 2);

skullVolume = opts.BackgroundHU .* ones(opts.VolumeSize);

outerCortex = r >= opts.InnerRadius & r < opts.InnerRadius + opts.CortexThickness;
trabecular = r >= opts.InnerRadius + opts.CortexThickness & ...
    r < opts.OuterRadius - opts.CortexThickness;
innerCortex = r >= opts.OuterRadius - opts.CortexThickness & r <= opts.OuterRadius;

skullVolume(outerCortex) = opts.OuterCortexHU;
skullVolume(trabecular) = opts.TrabecularHU;
skullVolume(innerCortex) = opts.InnerCortexHU;

% Add a smooth spatial variation so property maps are not completely flat.
variation = opts.HUVariation .* sin(colGrid / 11) .* cos(sliceGrid / 13);
boneMask = outerCortex | trabecular | innerCortex;
skullVolume(boneMask) = skullVolume(boneMask) + variation(boneMask);

% Mark the target with the same high-valued convention used by the analysis.
skullVolume = markDemoTarget(skullVolume, target, opts.TargetMarkerValue, ...
    opts.TargetMarkerRadius);

info = struct();
info.description = 'Synthetic skull-like volume for code demonstration only.';
info.variableName = 'demo_skull_volume';
info.volumeSize = opts.VolumeSize;
info.target = target;
info.outputFile = opts.OutputFile;

if opts.SaveOutput
    demo_skull_volume = skullVolume;
    save(opts.OutputFile, 'demo_skull_volume', 'info', '-v7');
    fprintf('Saved demo volume: %s\n', opts.OutputFile);
end
end

function opts = parseDemoOptions(varargin)
projectRoot = fileparts(mfilename('fullpath'));

opts = struct();
opts.OutputFile = fullfile(projectRoot, 'demo_skull_volume.mat');
opts.SaveOutput = true;
opts.VolumeSize = [160 128 128];
opts.Target = [90 64 64];
opts.BackgroundHU = 20;
opts.InnerRadius = 42;
opts.OuterRadius = 56;
opts.CortexThickness = 4;
opts.RowRadiusScale = 1.00;
opts.ColumnRadiusScale = 1.08;
opts.SliceRadiusScale = 0.94;
opts.OuterCortexHU = 2200;
opts.TrabecularHU = 1550;
opts.InnerCortexHU = 2100;
opts.HUVariation = 120;
opts.TargetMarkerValue = 6000;
opts.TargetMarkerRadius = 2;

parser = inputParser();
parser.FunctionName = 'create_demo_skull_volume';
names = fieldnames(opts);
for i = 1:numel(names)
    addParameter(parser, names{i}, opts.(names{i}));
end
parse(parser, varargin{:});
opts = parser.Results;

opts.OutputFile = char(string(opts.OutputFile));
opts.VolumeSize = round(opts.VolumeSize(:)');
opts.Target = round(opts.Target(:)');
opts.TargetMarkerRadius = round(opts.TargetMarkerRadius);

if numel(opts.VolumeSize) ~= 3 || any(opts.VolumeSize < 32)
    error('VolumeSize must be a 1x3 vector with dimensions at least 32.');
end
if numel(opts.Target) ~= 3 || any(opts.Target < 1) || any(opts.Target > opts.VolumeSize)
    error('Target must be a valid [row column slice] coordinate inside VolumeSize.');
end
if opts.InnerRadius <= 0 || opts.OuterRadius <= opts.InnerRadius
    error('OuterRadius must be larger than InnerRadius.');
end
end

function volume = markDemoTarget(volume, target, value, radius)
r1 = max(1, target(1) - radius);
r2 = min(size(volume, 1), target(1) + radius);
c1 = max(1, target(2) - radius);
c2 = min(size(volume, 2), target(2) + radius);
s1 = max(1, target(3) - radius);
s2 = min(size(volume, 3), target(3) + radius);
volume(r1:r2, c1:c2, s1:s2) = value;
end
