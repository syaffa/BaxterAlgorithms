function FiberAnalysisGUI(aSeqPaths)
% GUI for FiberAnalysis, which plots fiber parameters.
%
% Inputs:
% aSeqPaths - Cell array with full path names of all image sequences that
%             should be included in the analysis.
%
% See also:
% FiberAnalysis, CentralNucleiGUI

% GUI figure.
mainFigure = figure('Name', 'Muscle fiber analysis',...
    'NumberTitle', 'off',...
    'MenuBar', 'none',...
    'ToolBar', 'none',...
    'Units', 'normalized',...
    'Position', [0.25 0.1 0.275 0.75]);

imData = ImageData(aSeqPaths{1});
% There should maybe be a warning if the other images have other channels.

vers = GetVersions(aSeqPaths);
vers = unique([vers{:}]);
if isempty(vers)
    vers = {''};
end

seqDirs = FileEnd(aSeqPaths);

plots = {...
    'Analyzed fiber regions'
    'Area per intensity'
    'Expression distribution'
    'Expression histograms'
    'Expression vs size'
    'Fiber outlines'
    'Fiber statistics (csv-file)'
    'Fiber size distribution'
    'Fiber size histograms'
    'Fiber sizes (csv-file)'
    'Heat maps'
    'Heat maps of positive fibers'
    'Weighted expression distribution'
    'Weighted fiber size distribution'};

% Input data for SettingsPanel, used to create ui-controls.
info.Image_sequences = Setting(...
    'name', 'Image sequences',...
    'type', 'list',...
    'default', seqDirs,...
    'alternatives_basic', seqDirs,...
    'tooltip', 'Images to include in analysis.');
info.Plots = Setting(...
    'name', 'Plots',...
    'type', 'list',...
    'default', plots,...
    'alternatives_basic', plots,...
    'tooltip', 'Plotting functions to run.');
info.Fiber_version = Setting(...
    'name', 'Fiber version',...
    'type', 'choice',...
    'default', vers{1},...
    'alternatives_basic', vers,...
    'tooltip', 'Label of pre-computed segmentation.');
info.Image_binning = Setting(...
    'name', 'Image binning',...
    'type', 'choice',...
    'default', 'conditions',...
    'alternatives_basic', {'conditions' 'none'},...
    'tooltip', 'Analyze per experimental condition or per image.');
info.Fluorescence_channel = Setting(...
    'name', 'Fluorescence channel',...
    'type', 'choice',...
    'default', imData.channelNames{1},...
    'alternatives_basic', imData.channelNames,...
    'tooltip', 'Fluorescence channel to be analyzed.');
info.Fiber_border_width = Setting(...
    'name', 'Fiber border width',...
    'type', 'numeric',...
    'default', inf,...
    'checkfunction', @(x) str2double(x) >= 1,...
    'tooltip', ['Width (in pixels) of analyzed border region. '...
    'Set to ''inf'' to analyze the whole fibers.']);
info.Analyze_only_whole_fibers = Setting(...
    'name', 'Analyze only whole fibers',...
    'type', 'check',...
    'default', true,...
    'tooltip', 'Exclude fibers touching the image border.');
info.Statistic = Setting(...
    'name', 'Statistic',...
    'type', 'choice',...
    'default', 'mean',...
    'alternatives_basic', {'mean' 'median'},...
    'tooltip', 'Statistic applied to pixel intensities.');
info.Threshold_fluorescence = Setting(...
    'name', 'Threshold fluorescence',...
    'type', 'choice',...
    'default', 'no',...
    'alternatives_basic', {'auto', 'manual', 'no'},...
    'tooltip', 'Thresholding method to select a positive subset of fibers to analyze.');
info.Global_threshold = Setting(...
    'name', 'Global threshold',...
    'type', 'choice',...
    'default', 'no',...
    'alternatives_basic', {'yes', 'no'},...
    'visiblefunction', @(x) strcmp(x.Get('Threshold_fluorescence'), 'auto'),...
    'tooltip', 'Uses the same threshold on all images.');
info.Normalize_by_threshold = Setting(...
    'name', 'Normalize by threshold',...
    'type', 'choice',...
    'default', 'no',...
    'alternatives_basic', {'yes', 'no'},...
    'visiblefunction', @(x) strcmp(x.Get('Threshold_fluorescence'), 'auto'),...
    'tooltip', 'Divides the intensities by the thresholds.');
info.Save_classified_fibers = Setting(...
    'name', 'Save classified fibers',...
    'type', 'choice',...
    'default', 'no',...
    'alternatives_basic', {'yes', 'no'},...
    'visiblefunction', @(x) strcmp(x.Get('Threshold_fluorescence'), 'auto'),...
    'tooltip', 'Saves fibers under a new label after classifying them as +/-.');
info.Save_version = Setting(...
    'name', 'Save version',...
    'type', 'char',...
    'default', datestr(now, '_yymmdd_HHMMss'),...
    'checkfunction',  @(x) ~isempty(x) && isvarname(['a' x]),...
    'visiblefunction', @(x) strcmp(x.Get('Threshold_fluorescence'), 'auto') &&...
    strcmp(x.Get('Save_classified_fibers'), 'yes'),...
    'tooltip', 'Label of saved classified fibers.');

% Create a panel with all ui-objects.
sPanel = SettingsPanel(info,...
    'Parent', mainFigure,...
    'Position', [0 0.10 1 0.90],...
    'Split', 0.325,...
    'MinList', 10);

% Button to start computation.
uicontrol(...
    'BackgroundColor', get(mainFigure, 'color'),...
    'Style', 'pushbutton',...
    'Units', 'normalized',...
    'Position', [0 0 0.5 0.1],...
    'String', 'Start',...
    'Callback', @StartButton_Callback,...
    'Tooltip', 'Starts computation and plotting.');

% Opens a GUI to save all plots that have been created.
saveButton = uicontrol(...
    'Parent', mainFigure,...
    'String', 'Save plots',...
    'BackgroundColor', get(mainFigure, 'color'),...
    'Style', 'pushbutton',...
    'Units', 'normalized',...
    'Position', [0.5 0 0.5 0.1],...
    'Enable', 'off',...  % At the start there are no plots to save.
    'Callback', @SaveButton_Callback,...
    'Tooltip', 'Opens a GUI where the created plots can be saved.');

figs = [];

    function SaveButton_Callback(~, ~)
        % Opens a GUI to save the plots that have been generated.
        
        % Take the author string from the first image sequence.
        imData = ImageData(aSeqPaths{1});
        
        figs = intersect(figs, get(0, 'Children'));
        
        % The order of the figures is changed by intersect and therefore
        % the figures must be sorted.
        [~, order] = sort([figs.Number]);
        figs = figs(order);
        
        SavePlotsGUI('Plots', num2cell(figs),...
            'Directory', fullfile(imData.GetExPath(), 'Analysis'),...
            'Title', 'Fiber Plots',...
            'AuthorStr', imData.Get('authorStr'))
    end

    function StartButton_Callback(~, ~)
        % Callback which starts the processing.
        
        sequenceIndices = sPanel.GetIndex('Image_sequences');
        sequences = aSeqPaths(sequenceIndices);
        selectedPlotIndices = sPanel.GetIndex('Plots');
        selectedPlots = plots(selectedPlotIndices);
        fiberVersion = sPanel.GetValue('Fiber_version');
        imageBinning = sPanel.GetValue('Image_binning');
        channel = sPanel.GetValue('Fluorescence_channel');
        boderWidth = sPanel.GetValue('Fiber_border_width');
        onlyWholeFibers = sPanel.GetValue('Analyze_only_whole_fibers');
        statistic = sPanel.GetValue('Statistic');
        threshold = sPanel.GetValue('Threshold_fluorescence');
        globalThreshold = strcmp(sPanel.GetValue('Global_threshold'), 'yes');
        normalize = strcmp(sPanel.GetValue('Normalize_by_threshold'), 'yes');
        saveFibers = strcmp(sPanel.GetValue('Save_classified_fibers'), 'yes');
        if saveFibers
            saveVersion = sPanel.GetValue('Save_version');
        else
            saveVersion = [];
        end
        
        if any(strcmp(selectedPlots, 'Fiber statistics (csv-file)'))
            % Ask the user where to save the csv-file with statistics.
            defaultFile = fullfile(...
                imData.GetAnalysisPath(), ['Fiber statistics ' channel '.csv']);
            [file, directory] = uiputfile(...
                '*.csv', 'Save Fiber Statistics', defaultFile);
            if isequal(file, 0)
                % Abort all processing if the user cancels or closes the
                % name selection dialog.
                return
            end
            csvPath = fullfile(directory, file);
            csvArgs = {'StatisticsCsvPath', csvPath};
        else
            csvArgs = {};
        end
        
        if any(strcmp(selectedPlots, 'Fiber sizes (csv-file)'))
            % Ask the user where to save the csv-file with fiber sizes.
            defaultFile = fullfile(...
                imData.GetAnalysisPath(), 'Fiber sizes.csv');
            [file, directory] = uiputfile(...
                '*.csv', 'Save Fiber Sizes', defaultFile);
            if isequal(file, 0)
                % Abort all processing if the user cancels or closes the
                % name selection dialog.
                return
            end
            csvPath = fullfile(directory, file);
            csvArgs = [csvArgs, {'SizeCsvPath', csvPath}];
        end
        
        newFigs = FiberAnalysis(sequences, fiberVersion, channel, selectedPlots,...
            'ImageBinning', imageBinning,...
            'BorderWidth', boderWidth,...
            'AnalyzeOnlyWholeFibers', onlyWholeFibers,...
            'Statistic', statistic,...
            'Threshold', threshold,...
            'GlobalThreshold', globalThreshold,...
            'Normalize', normalize,...
            'SaveVersion', saveVersion,...
            csvArgs{:});
        figs = [figs; newFigs];
        
        % Allow saving once there are plots to save. The GUI will not
        % notice if all plots are closed.
        if ~isempty(figs)
            set(saveButton, 'Enable', 'on')
        end
    end
end