function result = run_skull_properties_analysis(inputData, varargin)
%RUN_SKULL_PROPERTIES_ANALYSIS Fast, cleaned skull-properties analysis.
%
% This is an efficiency-oriented seed-to-target
% pipeline: skull CT volume -> seed rays -> skull surface properties


projectRoot = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(inputData)
    % Default to the example CT-derived skull volume copied into the project.
    inputData = fullfile(projectRoot, 'demo_skull_volume.mat');
    if ~isfile(inputData)
        create_demo_skull_volume('OutputFile', inputData);
    end
end

% Parse name-value options, normalize text options, and validate simple ranges.
opts = parseOptions(varargin{:});
if opts.AddProjectToPath
    % Keeps the original helper functions available when the user calls this
    % function from another folder.
    addpath(projectRoot);
end

% Fail early if required toolboxes/add-ons are not visible on the MATLAB path.
validateCleanDependencies();

logMessage(opts, '=== Clean skull properties analysis started ===');

% The loader accepts MAT/NIfTI/numeric array input. MAT files are scanned for
% a likely 3-D skull volume if the user does not name the variable explicitly.
[skullVolume, inputInfo] = loadSkullVolume(inputData, opts.InputVariable);
skullVolume = double(skullVolume);

if opts.ApplySkullExtraction
    % Use this path for raw/preprocessed CT volumes that still include air,
    % bed, or non-skull regions. The default sample is already prepared.
    logMessage(opts, '[1/5] Extracting skull volume from CT intensities');
    skullVolume = generate_skull_volume(skullVolume);
else
    logMessage(opts, '[1/5] Using input as prepared skull volume');
end

brainTarget = opts.BrainTarget;
if isempty(brainTarget)
    % Existing datasets mark the focal target with a small block of high
    % intensity voxels, usually 6000. The centroid of that block is used.
    brainTarget = findTargetMarker(skullVolume, opts.TargetMarkerValue);
end
if isempty(brainTarget)
    error('A target is required. Pass BrainTarget or provide a %.0f-valued marker.', ...
        opts.TargetMarkerValue);
end
brainTarget = validatePoint(brainTarget, size(skullVolume), 'BrainTarget');

if opts.MarkTarget
    % Re-write the marker to ensure downstream logic can find it even if the
    % user supplied BrainTarget but the input volume was not already marked.
    skullVolume = markTarget(skullVolume, brainTarget, opts.TargetMarkerValue, ...
        opts.TargetMarkerRadius);
end

logMessage(opts, '[2/5] Generating seed rays');
% Seeds are distributed on a sphere around the target using a Fibonacci
% lattice. Only the half-space in front of the skull is retained, matching
% the intent of the original grow_seeds_around_target workflow.
rays = generateTargetSeedRays(size(skullVolume), brainTarget, opts);
logMessage(opts, sprintf('      Candidate rays after de-duplication: %d', rays.numRays));

if opts.UseClosedMask
    % The closed mask is used only as a surface-point validity check. It helps
    % reject projected points that land in small gaps around the skull mask.
    logMessage(opts, '[3/5] Building closed skull mask for surface validation');
    closedMask = buildClosedMask(skullVolume, opts);
else
    closedMask = [];
end

logMessage(opts, '[4/5] Sampling rays and estimating skull properties');
% This is the main optimized step: sample intensities directly along each
% seed-to-target ray, then pass the resulting line profiles into the original
% HU/SDR/layer-property estimator.
candidates = processRayBatches(skullVolume, rays, closedMask, opts);
logMessage(opts, sprintf('      Accepted surface points: %d', numel(candidates.x)));

logMessage(opts, '[5/5] Packaging skull property result');
% Surface table is the most convenient output for plotting/exporting. The
% nested result fields preserve the same data in arrays for MATLAB workflows.
surfaceTable = makeSurfaceTable(candidates, opts);

result = struct();
result.input = inputInfo;
result.options = opts;
result.summary = struct( ...
    'inputSource', inputInfo.source, ...
    'inputVariableName', inputInfo.variableName, ...
    'skullVolumeSize', size(skullVolume), ...
    'brainTarget', brainTarget, ...
    'seedMode', 'target', ...
    'requestedSeeds', opts.SeedCount, ...
    'generatedRays', rays.numRays, ...
    'acceptedSurfacePoints', height(surfaceTable), ...
    'pathMethod', 'direct-ray-batch', ...
    'angleMethod', opts.AngleMethod);

result.geometry = struct();
result.geometry.brainTarget = brainTarget;
result.geometry.sizeFactor = rays.sizeFactor;
% centerExpanded and offsetExpandedToVolume explain how the artificial seed
% coordinate system maps back onto the original CT volume.
result.geometry.centerExpanded = rays.centerExpanded;
result.geometry.offsetExpandedToVolume = rays.offset;
result.geometry.seedExpanded = rays.seedExpanded;
result.geometry.seedOriginal = rays.seedOriginal;

result.surface = struct();
result.surface.table = surfaceTable;
result.surface.x = candidates.x;
result.surface.y = candidates.y;
result.surface.z = candidates.z;
% originalSubscripts are [row, column, slice] in the loaded skull volume.
result.surface.originalSubscripts = [candidates.row, candidates.col, candidates.slice];

result.properties = struct();
result.properties.thicknessVoxels = candidates.thicknessVoxels;
result.properties.thicknessMm = candidates.thicknessVoxels .* opts.VoxelSizeMm;
result.properties.densityRatio = candidates.densityRatio;
result.properties.meanHU = candidates.meanHU;
result.properties.outerAngleDeg = candidates.outerAngleDeg;
result.properties.innerAngleDeg = candidates.innerAngleDeg;
result.properties.outerDensity = candidates.rho4;
result.properties.trabecularDensity = candidates.rho3;
result.properties.innerDensity = candidates.rho2;
result.properties.outerSpeed = candidates.v4;
result.properties.trabecularSpeed = candidates.v3;
result.properties.innerSpeed = candidates.v2;
result.properties.outerThicknessM = candidates.th4;
result.properties.trabecularThicknessM = candidates.th3;
result.properties.innerThicknessM = candidates.th2;
result.properties.totalThicknessM = candidates.th;

if opts.SaveOutput
    saveCleanResult(result, opts.OutputDir);
end

logMessage(opts, '=== Clean skull properties analysis finished ===');
end

function opts = parseOptions(varargin)
%PARSEOPTIONS Convert user inputs into a normalized options struct.
%
% Supports either:
%   run_skull_properties_analysis(file, 'SeedCount', 2000)
% or:
%   opts = struct('SeedCount', 2000);
%   run_skull_properties_analysis(file, opts)
opts = defaultOptions();

if isscalar(varargin) && isstruct(varargin{1})
    names = fieldnames(varargin{1});
    for i = 1:numel(names)
        if ~isfield(opts, names{i})
            error('Unknown option "%s".', names{i});
        end
        opts.(names{i}) = varargin{1}.(names{i});
    end
else
    parser = inputParser();
    parser.FunctionName = 'run_skull_properties_analysis';
    names = fieldnames(opts);
    for i = 1:numel(names)
        addParameter(parser, names{i}, opts.(names{i}));
    end
    parse(parser, varargin{:});
    opts = parser.Results;
end

opts.InputVariable = char(string(opts.InputVariable));
opts.AngleMethod = lower(char(string(opts.AngleMethod)));
opts.InterpMethod = char(string(opts.InterpMethod));
opts.OutputDir = char(string(opts.OutputDir));

% Round count/radius options so accidental decimal input does not propagate
% into indexing expressions.
opts.SeedCount = round(opts.SeedCount);
opts.BatchSize = round(opts.BatchSize);
opts.TargetMarkerRadius = round(opts.TargetMarkerRadius);
opts.CloseRadius = round(opts.CloseRadius);
opts.PcaRadius = round(opts.PcaRadius);

if opts.SeedCount < 1
    error('SeedCount must be positive.');
end
if opts.BatchSize < 1
    error('BatchSize must be positive.');
end
if ~any(strcmp(opts.AngleMethod, {'default', 'pca'}))
    error('AngleMethod must be "default" or "pca".');
end
end

function opts = defaultOptions()
%DEFAULTOPTIONS Central place for all model constants and user-facing knobs.
projectRoot = fileparts(mfilename('fullpath'));
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));

opts = struct();
opts.InputVariable = '';
opts.BrainTarget = [];
opts.SeedCount = 400000;
opts.BatchSize = 10000;
opts.ApplySkullExtraction = false;
opts.MarkTarget = true;

% Target marker convention from the original scripts.
opts.TargetMarkerValue = 6000;
opts.TargetMarkerRadius = 2;

% Thresholds used for identifying skull/bone along a ray. These should be
% reviewed if the CT intensity scaling changes.
opts.BoneThreshold = 1400;
opts.MaskThreshold = 1500;

% Padding creates an expanded seed coordinate system around the target so
% seed rays can start outside the skull volume.
opts.TargetPaddingVoxels = 30;

% calculate_skull_propeties expects the high-valued target marker near the
% tail of each profile; trim extra tail samples before segmenting skull.
opts.ProfileTailTrim = 50;
opts.DefaultMissingAngleDegrees = 60;

% 'default' keeps angle handling fast and reproduces the prior missing-angle
% convention. 'pca' estimates a local skull normal but is slower.
opts.AngleMethod = 'default';
opts.PcaRadius = 4;
opts.MinPcaPoints = 12;

% Mask closing is used only to validate candidate surface points.
opts.UseClosedMask = true;
opts.CloseRadius = 10;

% Current project assumes 0.44 mm isotropic voxel spacing for thickness.
opts.VoxelSizeMm = 0.44;
opts.InterpMethod = 'linear';
opts.SaveOutput = false;
opts.OutputDir = fullfile(projectRoot, 'results_properties', timestamp);
opts.AddProjectToPath = true;
opts.Verbose = true;
end

function [skullVolume, info] = loadSkullVolume(inputData, requestedName)
%LOADSKULLVOLUME Load the skull volume and record where it came from.
info = struct('source', '', 'variableName', '', 'size', []);

if isnumeric(inputData)
    % Allows advanced users/tests to pass a volume directly.
    validateVolume(inputData, 'inputData');
    skullVolume = inputData;
    info.source = 'numeric array';
    info.size = size(skullVolume);
    return
end

inputPath = char(string(inputData));
if ~isfile(inputPath)
    error('Input file not found: %s', inputPath);
end

[~, ~, ext] = fileparts(inputPath);
info.source = inputPath;

switch lower(ext)
    case '.mat'
        % MAT input can contain many variables; choose a likely 3-D volume.
        [variableName, skullVolume] = loadVolumeFromMat(inputPath, requestedName);
        info.variableName = variableName;
    case {'.nii', '.gz'}
        skullVolume = niftiread(inputPath);
    otherwise
        error('Unsupported input type "%s". Use MAT or NIfTI input.', ext);
end

validateVolume(skullVolume, inputPath);
info.size = size(skullVolume);
end

function [variableName, skullVolume] = loadVolumeFromMat(inputPath, requestedName)
%LOADVOLUMEFROMMAT Load a named volume, or infer the most likely volume.
vars = whos('-file', inputPath);
if isempty(vars)
    error('MAT file contains no variables.');
end

if ~isempty(requestedName)
    match = find(strcmp({vars.name}, requestedName), 1);
    if isempty(match)
        error('Variable "%s" not found in %s.', requestedName, inputPath);
    end
    variableName = requestedName;
else
    variableName = chooseVolumeVariable(vars);
end

data = load(inputPath, variableName);
skullVolume = data.(variableName);
end

function variableName = chooseVolumeVariable(vars)
%CHOOSEVOLUMEVARIABLE Prefer project-specific names, then any numeric 3-D array.
preferred = {'demo_skull_volume', 'sample_skull_volume', 'ct_volume', ...
    'skull_volume', 'skull_volume_2', 'skull_resized', 'ct_data'};
for i = 1:numel(preferred)
    match = find(strcmp({vars.name}, preferred{i}), 1);
    if ~isempty(match) && isVolumeCandidate(vars(match))
        variableName = vars(match).name;
        return
    end
end
for i = 1:numel(vars)
    if isVolumeCandidate(vars(i))
        variableName = vars(i).name;
        return
    end
end
error('No numeric 3-D volume variable was found.');
end

function tf = isVolumeCandidate(varInfo)
%ISVOLUMECANDIDATE True for numeric 3-D arrays stored in MAT metadata.
tf = numel(varInfo.size) == 3 && all(varInfo.size > 1) && ...
    any(strcmp(varInfo.class, {'double', 'single', 'uint8', 'uint16', ...
    'uint32', 'int16', 'int32', 'logical'}));
end

function validateVolume(value, label)
%VALIDATEVOLUME Ensure later 3-D interpolation/indexing will be meaningful.
if ~isnumeric(value) || ndims(value) ~= 3 || any(size(value) < 2)
    error('%s must be a numeric 3-D volume.', label);
end
end

function target = findTargetMarker(volume, markerValue)
%FINDTARGETMARKER Locate the centroid of the high-valued focal marker.
idx = find(volume >= markerValue - 200);
if isempty(idx)
    target = [];
    return
end
[r, c, s] = ind2sub(size(volume), idx);
target = round([mean(r), mean(c), mean(s)]);
end

function point = validatePoint(point, volumeSize, label)
%VALIDATEPOINT Check a user-provided [row column slice] coordinate.
point = round(point(:)');
if numel(point) ~= 3
    error('%s must be [row column slice].', label);
end
if any(point < 1) || point(1) > volumeSize(1) || ...
        point(2) > volumeSize(2) || point(3) > volumeSize(3)
    error('%s [%d %d %d] is outside volume size [%d %d %d].', ...
        label, point(1), point(2), point(3), volumeSize(1), volumeSize(2), volumeSize(3));
end
end

function volume = markTarget(volume, target, value, radius)
%MARKTARGET Write a small cube marker around the selected target coordinate.
r1 = max(1, target(1) - radius);
r2 = min(size(volume, 1), target(1) + radius);
c1 = max(1, target(2) - radius);
c2 = min(size(volume, 2), target(2) + radius);
s1 = max(1, target(3) - radius);
s2 = min(size(volume, 3), target(3) + radius);
volume(r1:r2, c1:c2, s1:s2) = value;
end

function rays = generateTargetSeedRays(volumeSize, brainTarget, opts)
%GENERATETARGETSEEDRAYS Create seed points and direct rays toward the target.
%
% The Fibonacci lattice gives nearly uniform angular coverage. The returned
% rays are stored in the expanded coordinate system used by the original code,
% plus a mapping back to the original skull volume.
n = opts.SeedCount * 2;
i = (1:n)';
goldenAngle = pi * (3 - sqrt(5));

theta = goldenAngle .* i;
zUnit = 1 - (i ./ (n - 1)) .* 2;
xUnit = sqrt(max(0, 1 - zUnit .^ 2)) .* cos(theta);
yUnit = sqrt(max(0, 1 - zUnit .^ 2)) .* sin(theta);

remaining = [volumeSize(1) - brainTarget(1), ...
    volumeSize(2) - brainTarget(2), ...
    volumeSize(3) - brainTarget(3)];

% Match the original size-factor rule: make the expanded coordinate system
% large enough to contain the full skull volume around the target.
if max(brainTarget) - max(remaining) < 0
    sizeFactor = max(remaining) + opts.TargetPaddingVoxels;
else
    sizeFactor = max(brainTarget) + opts.TargetPaddingVoxels;
end

x = ceil(abs(xUnit .* sizeFactor + sizeFactor)) + 1;
y = ceil(abs(yUnit .* sizeFactor + sizeFactor)) + 1;
z = ceil(abs(zUnit .* sizeFactor + sizeFactor)) + 1;

seedsVolumeHeight = sizeFactor - brainTarget(1) + volumeSize(1);
trimIdx = find(z > seedsVolumeHeight, 1, 'last');
if ~isempty(trimIdx)
    % Keep the same front half-space trimming used in the target-seed workflow.
    x = x(trimIdx+1:end);
    y = y(trimIdx+1:end);
    z = z(trimIdx+1:end);
end

[uniqueSeeds, uniqueIdx] = unique([x, y, z], 'rows', 'stable');
x = uniqueSeeds(:, 1);
y = uniqueSeeds(:, 2);
z = uniqueSeeds(:, 3);

centerExpanded = [sizeFactor, sizeFactor, sizeFactor];
offset = [sizeFactor - brainTarget(1), ...
    sizeFactor - brainTarget(2), ...
    sizeFactor - brainTarget(3)];

seedExpanded = [z, x, y];
seedOriginal = seedExpanded - offset;
direction = centerExpanded - seedExpanded;
rayLength = sqrt(sum(direction .^ 2, 2));
directionUnit = direction ./ max(rayLength, eps);

rays = struct();
rays.sizeFactor = sizeFactor;
rays.centerExpanded = centerExpanded;
rays.offset = offset;
rays.x = x;
rays.y = y;
rays.z = z;
rays.uniqueIdx = uniqueIdx;
rays.seedExpanded = seedExpanded;
rays.seedOriginal = seedOriginal;
rays.directionExpanded = directionUnit;
rays.rayLength = rayLength;
rays.numRays = numel(x);
end

function closedMask = buildClosedMask(volume, opts)
%BUILDCLOSEDMASK Smooth binary skull support for validating surface points.
mask = volume >= opts.MaskThreshold & volume < opts.TargetMarkerValue - 200;
closedMask = false(size(mask));
se = strel('disk', opts.CloseRadius);
for r = 1:size(mask, 1)
    % Closing each row-plane follows the behavior of the original
    % plant_seed_data2skull helper.
    closedMask(r, :, :) = imclose(squeeze(mask(r, :, :)), se);
end
end

function candidates = processRayBatches(volume, rays, closedMask, opts)
%PROCESSRAYBATCHES Sample ray profiles, compute properties, and collect points.
candidateBatches = {};
numBatches = ceil(rays.numRays / opts.BatchSize);

for batchID = 1:numBatches
    firstIdx = (batchID - 1) * opts.BatchSize + 1;
    lastIdx = min(batchID * opts.BatchSize, rays.numRays);
    idx = firstIdx:lastIdx;

    if opts.Verbose
        fprintf('      Batch %d/%d: rays %d-%d\n', batchID, numBatches, firstIdx, lastIdx);
    end

    rayBatch = sliceRays(rays, idx);
    [profiles, rayInfo] = sampleRayProfiles(volume, rayBatch, opts);

    keep = rayInfo.hasBone;
    if ~any(keep)
        continue
    end

    profiles = profiles(keep, :);
    rayInfo = sliceRayInfo(rayInfo, keep);
    rayBatch = sliceRays(rayBatch, find(keep));

    % calculate_skull_propeties only uses x1 for output sizing, so a dummy
    % vector is enough when profiles are already sampled.
    dummyX = zeros(size(profiles, 1), 1);
    [v4, v3, v2, th4, th3, th2, thTotal, rho4, rho3, rho2, ...
        thicknessVoxels, densityRatio, distance, meanHU] = ...
        calculate_skull_propeties(profiles, dummyX);

    batchCandidates = projectSurfaceCandidates(rayBatch, rayInfo, distance, ...
        thicknessVoxels, densityRatio, meanHU, rho4, rho3, rho2, ...
        v4, v3, v2, th4, th3, th2, thTotal, opts);

    if ~isempty(batchCandidates.x)
        candidateBatches{end+1} = batchCandidates; %#ok<AGROW>
    end
end

candidates = concatenateCandidates(candidateBatches);
candidates = validateAndDedupeCandidates(candidates, volume, closedMask, opts);
candidates = assignAngles(candidates, volume, opts);
end

function raySubset = sliceRays(rays, idx)
%SLICERAYS Return a ray struct containing only selected ray rows.
raySubset = rays;
fields = {'x', 'y', 'z', 'seedExpanded', 'seedOriginal', ...
    'directionExpanded', 'rayLength'};
for i = 1:numel(fields)
    raySubset.(fields{i}) = rays.(fields{i})(idx, :);
end
raySubset.numRays = numel(idx);
end

function [profiles, rayInfo] = sampleRayProfiles(volume, rays, opts)
%SAMPLERAYPROFILES Interpolate CT values along each seed-to-target line.
%
% profiles is one row per ray. rayInfo stores the first/last bone point so
% later stages can project properties back to the skull surface.
maxSamples = ceil(max(rays.rayLength)) + 1;
maxSamples = max(maxSamples, opts.ProfileTailTrim + 2);
profiles = zeros(rays.numRays, maxSamples);

rayInfo = struct();
rayInfo.hasBone = false(rays.numRays, 1);
rayInfo.outerOriginal = nan(rays.numRays, 3);
rayInfo.innerOriginal = nan(rays.numRays, 3);
rayInfo.directionOriginal = nan(rays.numRays, 3);

for i = 1:rays.numRays
    nSamples = ceil(rays.rayLength(i)) + 1;
    t = linspace(0, 1, nSamples)';
    expanded = rays.seedExpanded(i, :) + ...
        t .* (rays.centerExpanded - rays.seedExpanded(i, :));
    original = expanded - rays.offset;

    % Direct interpolation avoids rotating a 3-D sub-volume for every seed.
    values = interpn(volume, original(:, 1), original(:, 2), original(:, 3), ...
        opts.InterpMethod, 0);

    % Preserve the old line-profile assumption that the focal target marker
    % appears at the end of the sampled ray.
    values(end) = max(values(end), opts.TargetMarkerValue);

    profiles(i, 1:nSamples) = values(:).';

    boneMask = values > opts.BoneThreshold & values < opts.TargetMarkerValue - 200;
    if any(boneMask)
        firstBone = find(boneMask, 1, 'first');
        lastBone = find(boneMask, 1, 'last');
        rayInfo.hasBone(i) = true;
        rayInfo.outerOriginal(i, :) = original(firstBone, :);
        rayInfo.innerOriginal(i, :) = original(lastBone, :);
    end

    dir = rays.centerExpanded - rays.seedExpanded(i, :);
    dir = dir ./ max(norm(dir), eps);
    rayInfo.directionOriginal(i, :) = dir;
end
end

function rayInfo = sliceRayInfo(rayInfo, idx)
%SLICERAYINFO Return selected rows from the ray metadata struct.
fields = fieldnames(rayInfo);
for i = 1:numel(fields)
    rayInfo.(fields{i}) = rayInfo.(fields{i})(idx, :);
end
end

function candidates = projectSurfaceCandidates(rays, rayInfo, distance, thicknessVoxels, ...
    densityRatio, meanHU, rho4, rho3, rho2, v4, v3, v2, th4, th3, th2, thTotal, opts)
%PROJECTSURFACECANDIDATES Map per-ray properties onto skull surface points.
valid = distance > 0 & thicknessVoxels > 0;

if ~any(valid)
    candidates = emptyCandidates();
    return
end

x = rays.x(valid);
y = rays.y(valid);
z = rays.z(valid);
dFactor = distance(valid) ./ rays.sizeFactor;

% This projection follows the original plant_seed_data2skull formula.
surfaceX = round(x .* dFactor + (1 - dFactor) .* rays.centerExpanded(2));
surfaceY = round(y .* dFactor + (1 - dFactor) .* rays.centerExpanded(3));
surfaceZ = round(z .* dFactor + (1 - dFactor) .* rays.centerExpanded(1));

surfaceExpanded = [surfaceZ, surfaceX, surfaceY];
surfaceOriginal = surfaceExpanded - rays.offset;

candidates = emptyCandidates();
candidates.x = surfaceX(:);
candidates.y = surfaceY(:);
candidates.z = surfaceZ(:);
candidates.row = round(surfaceOriginal(:, 1));
candidates.col = round(surfaceOriginal(:, 2));
candidates.slice = round(surfaceOriginal(:, 3));
candidates.outerPoint = rayInfo.outerOriginal(valid, :);
candidates.innerPoint = rayInfo.innerOriginal(valid, :);
candidates.rayDirection = rayInfo.directionOriginal(valid, :);
candidates.thicknessVoxels = thicknessVoxels(valid);
candidates.densityRatio = densityRatio(valid);
candidates.meanHU = meanHU(valid);
candidates.rho4 = rho4(valid);
candidates.rho3 = rho3(valid);
candidates.rho2 = rho2(valid);
candidates.v4 = v4(valid);
candidates.v3 = v3(valid);
candidates.v2 = v2(valid);
candidates.th4 = th4(valid) .* opts.VoxelSizeMm .* 1e-3;
candidates.th3 = th3(valid) .* opts.VoxelSizeMm .* 1e-3;
candidates.th2 = th2(valid) .* opts.VoxelSizeMm .* 1e-3;
candidates.th = thTotal(valid) .* opts.VoxelSizeMm .* 1e-3;
candidates.outerAngleDeg = opts.DefaultMissingAngleDegrees .* ones(nnz(valid), 1);
candidates.innerAngleDeg = opts.DefaultMissingAngleDegrees .* ones(nnz(valid), 1);
end

function candidates = emptyCandidates()
%EMPTYCANDIDATES Build an empty candidate struct with stable field names.
fields = {'x', 'y', 'z', 'row', 'col', 'slice', 'thicknessVoxels', ...
    'densityRatio', 'meanHU', 'rho4', 'rho3', 'rho2', 'v4', 'v3', 'v2', ...
    'th4', 'th3', 'th2', 'th', 'outerAngleDeg', 'innerAngleDeg'};
for i = 1:numel(fields)
    candidates.(fields{i}) = zeros(0, 1);
end
candidates.outerPoint = zeros(0, 3);
candidates.innerPoint = zeros(0, 3);
candidates.rayDirection = zeros(0, 3);
end

function candidates = concatenateCandidates(candidateBatches)
%CONCATENATECANDIDATES Merge per-batch structs into one candidate struct.
candidates = emptyCandidates();
if isempty(candidateBatches)
    return
end

fields = fieldnames(candidates);
for i = 1:numel(fields)
    values = cellfun(@(c) c.(fields{i}), candidateBatches, 'UniformOutput', false);
    candidates.(fields{i}) = vertcat(values{:});
end
end

function candidates = validateAndDedupeCandidates(candidates, volume, closedMask, opts)
%VALIDATEANDDEDUPECANDIDATES Remove out-of-volume and duplicate surface points.
if isempty(candidates.x)
    return
end

inside = candidates.row >= 1 & candidates.row <= size(volume, 1) & ...
    candidates.col >= 1 & candidates.col <= size(volume, 2) & ...
    candidates.slice >= 1 & candidates.slice <= size(volume, 3);

if opts.UseClosedMask
    % Optional anatomical sanity check: keep only points lying on the closed
    % skull support mask.
    maskKeep = false(size(inside));
    idx = find(inside);
    lin = sub2ind(size(volume), candidates.row(idx), candidates.col(idx), candidates.slice(idx));
    maskKeep(idx) = closedMask(lin);
    inside = inside & maskKeep;
end

candidates = filterCandidates(candidates, inside);
if isempty(candidates.x)
    return
end

[~, uniqueIdx] = unique([candidates.x, candidates.y, candidates.z], 'rows', 'stable');
keep = false(size(candidates.x));
keep(uniqueIdx) = true;
candidates = filterCandidates(candidates, keep);
end

function candidates = filterCandidates(candidates, keep)
%FILTERCANDIDATES Apply the same logical row filter to every candidate field.
fields = fieldnames(candidates);
for i = 1:numel(fields)
    candidates.(fields{i}) = candidates.(fields{i})(keep, :);
end
end

function candidates = assignAngles(candidates, volume, opts)
%ASSIGNANGLES Attach insertion-angle estimates to each accepted surface point.
if isempty(candidates.x) || strcmp(opts.AngleMethod, 'default')
    % Fast path: retain the default angle convention already assigned during
    % candidate creation.
    return
end

% Optional slower path: estimate local surface normal by PCA around outer and
% inner skull hit points, then compare that normal with the ray direction.
mask = volume >= opts.MaskThreshold & volume < opts.TargetMarkerValue - 200;
outerAngles = opts.DefaultMissingAngleDegrees .* ones(numel(candidates.x), 1);
innerAngles = outerAngles;

for i = 1:numel(candidates.x)
    outerAngles(i) = localPcaAngle(mask, candidates.outerPoint(i, :), ...
        candidates.rayDirection(i, :), opts);
    innerAngles(i) = localPcaAngle(mask, candidates.innerPoint(i, :), ...
        candidates.rayDirection(i, :), opts);
end

candidates.outerAngleDeg = outerAngles;
candidates.innerAngleDeg = innerAngles;
end

function angleDeg = localPcaAngle(mask, point, rayDirection, opts)
%LOCALPCAANGLE Estimate local normal angle from nearby skull mask voxels.
point = round(point);
if any(~isfinite(point)) || any(point < 1) || point(1) > size(mask, 1) || ...
        point(2) > size(mask, 2) || point(3) > size(mask, 3)
    angleDeg = opts.DefaultMissingAngleDegrees;
    return
end

radius = opts.PcaRadius;
r1 = max(1, point(1) - radius);
r2 = min(size(mask, 1), point(1) + radius);
c1 = max(1, point(2) - radius);
c2 = min(size(mask, 2), point(2) + radius);
s1 = max(1, point(3) - radius);
s2 = min(size(mask, 3), point(3) + radius);

patch = mask(r1:r2, c1:c2, s1:s2);
[rr, cc, ss] = ind2sub(size(patch), find(patch));
if numel(rr) < opts.MinPcaPoints
    angleDeg = opts.DefaultMissingAngleDegrees;
    return
end

points = double([rr + r1 - 1, cc + c1 - 1, ss + s1 - 1]);
points = points - mean(points, 1);
covariance = (points' * points) ./ max(size(points, 1) - 1, 1);
[vectors, values] = eig(covariance);
[~, minIdx] = min(diag(values));
normal = vectors(:, minIdx)';
normal = normal ./ max(norm(normal), eps);
rayDirection = rayDirection ./ max(norm(rayDirection), eps);
angleDeg = acosd(min(1, abs(dot(normal, rayDirection))));
end

function surfaceTable = makeSurfaceTable(candidates, opts)
%MAKESURFACETABLE Produce a compact, user-friendly table of skull properties.
surfaceTable = table( ...
    candidates.x(:), candidates.y(:), candidates.z(:), ...
    candidates.row(:), candidates.col(:), candidates.slice(:), ...
    candidates.thicknessVoxels(:), candidates.thicknessVoxels(:) .* opts.VoxelSizeMm, ...
    candidates.densityRatio(:), candidates.meanHU(:), ...
    candidates.outerAngleDeg(:), candidates.innerAngleDeg(:), ...
    candidates.rho4(:), candidates.rho3(:), candidates.rho2(:), ...
    candidates.v4(:), candidates.v3(:), candidates.v2(:), ...
    candidates.th4(:), candidates.th3(:), candidates.th2(:), candidates.th(:), ...
    'VariableNames', {'X', 'Y', 'Z', 'VolumeRow', 'VolumeColumn', 'VolumeSlice', ...
    'ThicknessVoxels', 'ThicknessMm', 'DensityRatio', 'MeanHU', ...
    'OuterAngleDeg', 'InnerAngleDeg', 'OuterDensity', 'TrabecularDensity', ...
    'InnerDensity', 'OuterSpeed', 'TrabecularSpeed', 'InnerSpeed', ...
    'OuterThicknessM', 'TrabecularThicknessM', 'InnerThicknessM', 'ThicknessM'});
end

function validateCleanDependencies()
%VALIDATECLEANDEPENDENCIES Check non-base functions needed by properties only.
required = {'interpn', 'hounsfield2density', 'strel', 'imclose'};

missing = {};
for i = 1:numel(required)
    if isempty(which(required{i}))
        missing{end+1} = required{i}; %#ok<AGROW>
    end
end

if ~isempty(missing)
    error('Missing required MATLAB functions: %s.', strjoin(missing, ', '));
end
end

function saveCleanResult(result, outputDir)
%SAVECLEANRESULT Persist the result struct without large temporary variables.
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
save(fullfile(outputDir, 'skull_properties_result.mat'), 'result', '-v7.3');
end

function logMessage(opts, message)
%LOGMESSAGE Print progress only when Verbose is enabled.
if opts.Verbose
    fprintf('%s\n', message);
end
end
