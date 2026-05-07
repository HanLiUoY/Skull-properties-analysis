function h = plot_skull_analysis_result(result, varargin)
%PLOT_SKULL_ANALYSIS_RESULT Plot a skull-surface metric from run_skull_analysis.
%
% plot_skull_analysis_result(result)
% plot_skull_analysis_result(result, 'Metric', 'energyLoss', 'FrequencyKHz', 650)

opts = parsePlotOptions(varargin{:});

x = result.surface.x(:);
y = result.surface.y(:);
z = result.surface.z(:);

[values, labelText, titleText] = metricValues(result, opts.Metric, opts.FrequencyKHz);

h = figure('Name', ['Skull analysis: ', labelText], 'Units', 'centimeters', ...
    'Position', [5 2 12 10]);
axesHandle = axes('Parent', h);
scatter3(axesHandle, x, y, z, opts.MarkerSize, values(:), 'filled', ...
    'MarkerFaceAlpha', opts.MarkerAlpha, 'MarkerEdgeAlpha', opts.MarkerAlpha);
axis(axesHandle, 'equal');
axis(axesHandle, 'tight');
view(axesHandle, opts.View);
grid(axesHandle, 'off');
colormap(axesHandle, opts.Colormap);

set(axesHandle, 'Color', 'none', 'XAxisLocation', 'top', ...
    'XColor', 'none', 'YColor', 'none', 'ZColor', 'none', 'ZDir', 'reverse');

cb = colorbar(axesHandle);
ylabel(cb, labelText);
title(axesHandle, titleText, 'Interpreter', 'none');
end

function opts = parsePlotOptions(varargin)
opts = struct();
opts.Metric = 'energyLoss';
opts.FrequencyKHz = 650;
opts.MarkerSize = 6;
opts.MarkerAlpha = 0.85;
opts.View = [60 30];
opts.Colormap = jet;

parser = inputParser();
parser.FunctionName = 'plot_skull_analysis_result';
names = fieldnames(opts);
for i = 1:numel(names)
    addParameter(parser, names{i}, opts.(names{i}));
end
parse(parser, varargin{:});
opts = parser.Results;
opts.Metric = lower(char(string(opts.Metric)));
end

function [values, labelText, titleText] = metricValues(result, metric, frequencyKHz)
switch metric
    case {'thickness', 'thicknessmm'}
        values = result.properties.thicknessMm;
        labelText = 'Thickness (mm)';
        titleText = 'Skull thickness';
    case {'sdr', 'densityratio', 'density_ratio'}
        values = result.properties.densityRatio;
        labelText = 'Density ratio / SDR';
        titleText = 'Skull density ratio';
    case {'hu', 'meanh'}
        values = result.properties.meanHU;
        labelText = 'Mean HU';
        titleText = 'Mean skull HU';
    case {'angle', 'insertionangle'}
        values = (result.properties.outerAngleDeg + result.properties.innerAngleDeg) ./ 2;
        labelText = 'Mean insertion angle (deg)';
        titleText = 'Mean skull insertion angle';
    case {'pressure', 'pressureefficiency', 'transmission'}
        [values, actualKHz] = transmissionAtFrequency(result, 'pressureEfficiency', frequencyKHz);
        labelText = 'Pressure transmission efficiency';
        titleText = sprintf('Pressure efficiency at %.0f kHz', actualKHz);
    case {'energyefficiency', 'energy'}
        [values, actualKHz] = transmissionAtFrequency(result, 'energyEfficiency', frequencyKHz);
        labelText = 'Relative energy efficiency';
        titleText = sprintf('Energy efficiency at %.0f kHz', actualKHz);
    case {'energyloss', 'loss'}
        [values, actualKHz] = transmissionAtFrequency(result, 'energyLoss', frequencyKHz);
        labelText = 'Relative energy loss';
        titleText = sprintf('Energy loss at %.0f kHz', actualKHz);
    otherwise
        error('Unknown metric "%s".', metric);
end
end

function [values, actualKHz] = transmissionAtFrequency(result, fieldName, frequencyKHz)
data = result.transmission.(fieldName);
if isempty(data)
    error('Transmission data is empty. Re-run with CalculateTransmission set to true.');
end
[~, idx] = min(abs(result.transmission.frequenciesKHz - frequencyKHz));
values = squeeze(data(idx, :, :));
actualKHz = result.transmission.frequenciesKHz(idx);
end
