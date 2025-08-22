classdef DAQ_App_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        UIFigureGridLayout              matlab.ui.container.GridLayout
        ControlPanel                    matlab.ui.container.Panel
        ControlGridLayout               matlab.ui.container.GridLayout
        AcquisitionControlPanel         matlab.ui.container.Panel
        AcquisitionControlGridLayout    matlab.ui.container.GridLayout
        StatusLabel                     matlab.ui.control.Label
        StatusLamp                      matlab.ui.control.Lamp
        StopButton                      matlab.ui.control.Button
        StartButton                     matlab.ui.control.Button
        InitializeButton                matlab.ui.control.Button
        DataPathPanel                   matlab.ui.container.Panel
        DataPathGridLayout              matlab.ui.container.GridLayout
        PathStatusLabel                 matlab.ui.control.Label
        SelectPathButton                matlab.ui.control.Button
        SessionInfoPanel                matlab.ui.container.Panel
        SessionInfoGridLayout           matlab.ui.container.GridLayout
        FileStringEditField             matlab.ui.control.EditField
        SessionNameLabel                matlab.ui.control.Label
        SubjectIDEditField              matlab.ui.control.EditField
        SubjectIDLabel                  matlab.ui.control.Label
        TabGroup                        matlab.ui.container.TabGroup
        EMGGridLayout                   matlab.ui.container.Tab
        EMGGridLayout_1                 matlab.ui.container.GridLayout
        EMGDisplayOptionsPanel          matlab.ui.container.Panel
        EMGDiSplayOptionsGridLayout     matlab.ui.container.GridLayout
        EMGChannelsListBox              matlab.ui.control.ListBox
        EMGChannelsLabel                matlab.ui.control.Label
        EMGYMinEditField                matlab.ui.control.NumericEditField
        YminLabel_3                     matlab.ui.control.Label
        EMGYMaxEditField                matlab.ui.control.NumericEditField
        YmaxLabel_3                     matlab.ui.control.Label
        EMGGridLayout_2                 matlab.ui.container.GridLayout
        EMGAxes_3                       matlab.ui.control.UIAxes
        EMGAxes_4                       matlab.ui.control.UIAxes
        EMGAxes_2                       matlab.ui.control.UIAxes
        EMGAxes_1                       matlab.ui.control.UIAxes
        AnalogGridLayout                matlab.ui.container.Tab
        AnalogGridLayout_2              matlab.ui.container.GridLayout
        AnalogDisplayOptionsPanel       matlab.ui.container.Panel
        AnalogDisplayOptionsGridLayout  matlab.ui.container.GridLayout
        AnalogChannelsListBox           matlab.ui.control.ListBox
        AnalogChannelLabel              matlab.ui.control.Label
        AnalogYMinEditField             matlab.ui.control.NumericEditField
        YminLabel_2                     matlab.ui.control.Label
        AnalogYMaxEditField             matlab.ui.control.NumericEditField
        YmaxLabel_2                     matlab.ui.control.Label
        AnalogGridLayout_3              matlab.ui.container.GridLayout
        AnalogAxes_2                    matlab.ui.control.UIAxes
        AnalogAxes_1                    matlab.ui.control.UIAxes
        CombinedGridLayout              matlab.ui.container.Tab
        CombinedGridLayout_2            matlab.ui.container.GridLayout
        CombinedDisplayOptionsPanel     matlab.ui.container.Panel
        CombinedDisplayOptionsGridLayout  matlab.ui.container.GridLayout
        CombinedYMinEditField           matlab.ui.control.NumericEditField
        YminLabel                       matlab.ui.control.Label
        CombinedYMaxEditField           matlab.ui.control.NumericEditField
        YmaxLabel                       matlab.ui.control.Label
        CombinedListBox                 matlab.ui.control.ListBox
        CombinedChannelLabel            matlab.ui.control.Label
        CombinedAxes                    matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        % DAQ Objects
        dq               % DAQ object
        Fs = 2500        % Sampling rate (Hz)
        
        % File I/O and Metadata
        SubID            % Subject ID
        Filestr          % Session file string
        TrlNum = 1       % Trial number (starts at 1)
        pathname         % Data save directory
        meta_path        % Metadata directory
        OPfile           % Output file path
        
        % App State
        isInitialized = false % App ready flag
        
        % Plotting Handles and Buffers
        emgPlotHandles   % EMG plot handles (4)
        analogPlotHandles % Analog plot handles (2)
        combinedPlotHandles  % Combined plot handles (6)
        plotBuffer       % Plot data buffer
        timeBuffer       % Time buffer
        emgAxes          % EMG axes
        analogAxes       % Analog axes
        fid              % File identifier
        EMG_CH           % EMG channel numbers
        muscle_labels    % Muscle labels
        analog_input_labels % Analog input labels
        analog_scaling_factor = 0.1 % Analog scaling for EMG-ANA alignment
    end

    methods (Access = private)
        function setupPlots(app)
            % Initialize plot handles
            app.emgPlotHandles = gobjects(1, 4);
            app.analogPlotHandles = gobjects(1, 2);
            app.combinedPlotHandles = gobjects(1, 6);
            
            % Set up EMG plots
            for i = 1:4
                app.emgPlotHandles(i) = plot(app.emgAxes(i), NaN, NaN, 'b-');
            end
            
            % Set up analog plots
            for i = 1:2
                app.analogPlotHandles(i) = plot(app.analogAxes(i), NaN, NaN, 'r-');
            end
            
            % Set up combined plot
            hold(app.CombinedAxes, 'on');
            colors = {'#0072BD', '#D95319', '#EDB120', '#7E2F8E', '#77AC30', '#4DBEEE'};
            lineStyles = {'-', '-', '-', '-', '--', '--'};
            for i = 1:6
                app.combinedPlotHandles(i) = plot(app.CombinedAxes, NaN, NaN, ...
                    'Color', colors{i}, 'LineStyle', lineStyles{i}, 'LineWidth', 1.5);
            end
            title(app.CombinedAxes, 'Combined EMG & Analog Signals');
            xlabel(app.CombinedAxes, 'Time (s)');
            ylabel(app.CombinedAxes, 'Amplitude');
            grid(app.CombinedAxes, 'off');
            hold(app.CombinedAxes, 'off');
        end
    
        function PlotData(app, src, ~)
            % Read data and write to file
            [data, timestamps, ~] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
            fwrite(app.fid, [timestamps, data]', 'double');
            
            % Update plot buffer
            newSamples = size(data, 1);
            app.plotBuffer = [app.plotBuffer(newSamples+1:end, :); data];
            
            updatePlots(app);
            drawnow('limitrate');
        end
        
        % Update plots in real-time
        function updatePlots(app)
            selectedTab = app.TabGroup.SelectedTab;
            
            if selectedTab == app.EMGGridLayout
                % Update EMG plots
                selected_labels = app.EMGChannelsListBox.Value;
                for i = 1:4
                    ax = app.emgAxes(i);
                    handle = app.emgPlotHandles(i);
                    if i <= numel(selected_labels)
                        label = selected_labels{i};
                        logical_idx = strcmp(app.muscle_labels, label);
                        ch_num = app.EMG_CH(logical_idx);
                        plotData = app.plotBuffer(:, ch_num) - mean(app.plotBuffer(:, ch_num), 'omitnan');
                        
                        set(handle, 'XData', app.timeBuffer, 'YData', plotData);
                        title(ax, label, 'Interpreter', 'none');
                        applyYLimits(app, ax, app.EMGYMinEditField, app.EMGYMaxEditField);
                    else
                        set(handle, 'XData', NaN, 'YData', NaN);
                        title(ax, ['EMG CH' num2str(i)], 'Interpreter', 'none');
                    end
                end
                
            elseif selectedTab == app.AnalogGridLayout
                % Update analog plots
                selected_labels = app.AnalogChannelsListBox.Value;
                for i = 1:2
                    ax = app.analogAxes(i);
                    handle = app.analogPlotHandles(i);
                    if i <= numel(selected_labels)
                        label = selected_labels{i};
                        ch_idx = find(strcmp(app.analog_input_labels, label), 1);
                        
                        set(handle, 'XData', app.timeBuffer, 'YData', app.plotBuffer(:, ch_idx) * app.analog_scaling_factor);
                        title(ax, label, 'Interpreter', 'none');
                        applyYLimits(app, ax, app.AnalogYMinEditField, app.AnalogYMaxEditField);
                    else
                        set(handle, 'XData', NaN, 'YData', NaN);
                        title(ax, ['Analog CH' num2str(i)], 'Interpreter', 'none');
                    end
                end
                
            elseif selectedTab == app.CombinedGridLayout
                % Update combined plot
                selected_labels = app.CombinedListBox.Value;
                
                for i = 1:6, set(app.combinedPlotHandles(i), 'Visible', 'off'); end
                for i = 1:numel(selected_labels)
                    current_label = selected_labels{i};
                    
                    % Check EMG or Analog
                    logical_emg_idx = strcmp(app.muscle_labels, current_label);
                    analog_idx = find(strcmp(app.analog_input_labels, current_label), 1);
                    
                    if any(logical_emg_idx)
                        ch_num = app.EMG_CH(logical_emg_idx);
                        plotData = app.plotBuffer(:, ch_num) - mean(app.plotBuffer(:, ch_num), 'omitnan');
                    elseif ~isempty(analog_idx)
                        plotData = app.plotBuffer(:, analog_idx) * app.analog_scaling_factor;
                    else
                        continue;
                    end
                    set(app.combinedPlotHandles(i), 'XData', app.timeBuffer, 'YData', plotData, 'Visible', 'on');
                end
                
                legend(app.CombinedAxes, selected_labels, 'Location', 'northeast', 'Interpreter', 'none');
                applyYLimits(app, app.CombinedAxes, app.CombinedYMinEditField, app.CombinedYMaxEditField);
            end
        end
        
        % Sync combined list box
        function updateCombinedListBox(app)
            selectedEMG = app.EMGChannelsListBox.Value;
            selectedAnalog = app.AnalogChannelsListBox.Value;
            combinedItems = [selectedEMG'; selectedAnalog'];
            app.CombinedListBox.Items = combinedItems;
            app.CombinedListBox.Value = combinedItems;
        end
        
        % Apply Y-axis limits
        function applyYLimits(app, axesHandle, yMinField, yMaxField)
            yMin = yMinField.Value;
            yMax = yMaxField.Value;
            if ~isnan(yMin) && ~isnan(yMax) && yMin < yMax
                ylim(axesHandle, [yMin, yMax]);
            else
                ylim(axesHandle, 'auto');
            end
        end
        
        % Generate summary plot after stop
        function generateSummaryPlot(app)
            channelsToPlot = app.CombinedListBox.Value;
            if isempty(channelsToPlot), return; end
            if numel(channelsToPlot) > 6, channelsToPlot = channelsToPlot(1:6); end
            try
                fid_read = fopen(app.OPfile, 'r');
                numTotalChannels = numel(app.dq.Channels);
                rawData = fread(fid_read, [numTotalChannels + 1, inf], 'double');
                fclose(fid_read);
                
                allData = rawData';
                timeVector = allData(:, 1);
                dataMatrix = allData(:, 2:end);
                summaryFig = figure('Name', ['Trial Summary: ' app.Filestr '_Trl' num2str(app.TrlNum)], 'NumberTitle', 'off');
                tiledlayout(summaryFig, 'flow');
                for i = 1:numel(channelsToPlot)
                    current_label = channelsToPlot{i};
                    emg_idx = find(strcmp(app.muscle_labels, current_label));
                    analog_idx = find(strcmp(app.analog_input_labels, current_label));
                    
                    if ~isempty(emg_idx)
                        plotData = dataMatrix(:, app.EMG_CH(emg_idx));
                        plotData = plotData - mean(plotData, 'omitnan');
                    elseif ~isempty(analog_idx)
                        plotData = dataMatrix(:, analog_idx);
                    end
                    
                    nexttile;
                    plot(timeVector, plotData);
                    title(current_label, 'Interpreter', 'none');
                    xlabel('Time (s)'); ylabel('Amplitude');
                    grid on; axis tight;
                end
            catch ME
                warning('DAQ_App:summaryPlotError', 'Could not generate summary plot. Error: %s', ME.message);
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Load configuration
            if exist('CH_config.json', 'file')
                config_data = jsondecode(fileread('CH_config.json'));
                app.EMG_CH = config_data.EMG_CH;
                app.muscle_labels = config_data.muscle_labels;
                app.analog_input_labels = config_data.analog_input_labels;
            else
                % Default configuration
                app.EMG_CH = [17,27,29,23,41,43,37,47,57,51,61,63,65,75,77,71];
                app.muscle_labels = arrayfun(@(n) sprintf('EMG %d', n), 1:16, 'UniformOutput', false);
                app.analog_input_labels = arrayfun(@(n) sprintf('Analog %d', n), 1:16, 'UniformOutput', false);
            end
            % Configure UI components
            app.EMGChannelsListBox.Items = app.muscle_labels;
            app.EMGChannelsListBox.Value = app.muscle_labels(1:4);
            app.AnalogChannelsListBox.Items = app.analog_input_labels;
            app.AnalogChannelsListBox.Value = app.analog_input_labels(1:2);
            app.EMGChannelsListBox.ValueChangedFcn = @(~,~) updateCombinedListBox(app);
            app.AnalogChannelsListBox.ValueChangedFcn = @(~,~) updateCombinedListBox(app);
            
            % Setup plots and initial state
            app.emgAxes = [app.EMGAxes_1, app.EMGAxes_2, app.EMGAxes_3, app.EMGAxes_4];
            app.analogAxes = [app.AnalogAxes_1, app.AnalogAxes_2];
            updateCombinedListBox(app);
            setupPlots(app);
            
            app.StartButton.Enable = 'off';
            app.StopButton.Enable = 'off';
            app.PathStatusLabel.Text = 'Path not selected';
        end

        % Button pushed function: InitializeButton
        function InitializeButtonPushed(app, event)
            app.StatusLamp.Color = 'yellow';
            app.StatusLabel.Text = 'Connecting...';
            drawnow;
            
            if ~isempty(app.dq) && isvalid(app.dq), stop(app.dq); end
            
            try
                daqreset;
                d = daqlist("ni");
                if isempty(d), error('No NI DAQ devices found.'); end
                deviceID = d{1, "DeviceID"};
                
                app.dq = daq("ni");
                app.dq.Rate = app.Fs;
                addinput(app.dq, deviceID, 0:15, "Voltage");  % Analog
                addinput(app.dq, deviceID, 16:79, "Voltage"); % EMG
                
                app.dq.ScansAvailableFcnCount = app.Fs * 0.1;
                app.dq.ScansAvailableFcn = @(src, evt) logBroadcastAndPlotData(app, src, evt);
                
                app.isInitialized = true;
                app.StartButton.Enable = 'on';
                app.StatusLamp.Color = 'green';
                app.StatusLabel.Text = 'Ready';
            catch ME
                app.StatusLamp.Color = 'red';
                app.StatusLabel.Text = 'Error';
                uialert(app.UIFigure, ['DAQ Error: ' ME.message], "Initialization Failed");
            end
        end

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            if isempty(app.pathname)
                uialert(app.UIFigure, 'Please select a data path before starting.', 'Path Not Selected');
                return;
            end
            if ~app.isInitialized
                uialert(app.UIFigure, "Please initialize the DAQ first.", "Not Initialized");
                return;
            end
            
            % Create filename
            app.SubID = app.SubjectIDEditField.Value;
            app.Filestr = app.FileStringEditField.Value;
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            filename = sprintf('%s_%s_%s_Trl%03d.bin', timestamp, app.SubID, app.Filestr, app.TrlNum);
            app.OPfile = fullfile(app.pathname, filename);
            
            % Open file for writing
            try
                app.fid = fopen(app.OPfile, 'w');
                if app.fid == -1, error('Could not open file for writing.'); end
            catch ME
                uialert(app.UIFigure, ['File Error: ', ME.message], 'Error');
                return;
            end
            % Initialize plot buffers
            bufferDuration = 2;
            bufferSamples = bufferDuration * app.Fs;
            numChannels = numel(app.dq.Channels);
            app.plotBuffer = NaN(bufferSamples, numChannels);
            app.timeBuffer = (0:bufferSamples-1)' / app.Fs;
            
            % Update UI state
            start(app.dq, 'Continuous');
            app.StatusLamp.Color = [0.47, 0.67, 0.19]; % Green
            app.StartButton.Enable = 'off';
            app.StopButton.Enable = 'on';
            app.InitializeButton.Enable = 'off';
        end

        % Button pushed function: StopButton
        function StopButtonPushed(app, event)
            if ~isempty(app.dq) && app.dq.Running
                stop(app.dq);
            end
            if ~isempty(app.fid), fclose(app.fid); end
            app.StatusLabel.Text = 'Saved.';
            
            % Generate the summary plot
            generateSummaryPlot(app);
            
            % Save metadata
            meta_data = struct();
            meta_data.sub_id = app.SubID;
            meta_data.date = date;
            meta_data.timestamp = datestr(now, 'HHMMSS');
            meta_data.exp_name = app.Filestr;
            meta_data.trl_num = app.TrlNum;
            meta_data.fs = app.Fs;
            
            meta_data.total_num_emg_ch = length(app.muscle_labels);
            meta_data.emg_ch_number = app.EMG_CH;
            meta_data.musc_labels = app.muscle_labels;
            meta_data.musc_names = app.muscle_labels;
            
            meta_data.updaterate = 0.1;
            meta_data.updaterate_unit = 'seconds';
            
            meta_data.stim = 0; 
            meta_data.analog_input_labels = app.analog_input_labels;
            meta_data.analog_in_ch = 1:16;
            
            meta_data.pulse_width = 200;
            meta_data.pulse_width_unit = 'micro_seconds';
            meta_data.duty_cycle = 100;
            meta_data.dutycycle_unit = 'percent';
            
            meta_data.total_analog_in_ch = 80;
            
            % Save with consistent naming
            metadata_filename = sprintf('%s_%s_%s_METADATA_Trl%03d.mat', ...
                datestr(now, 'yyyymmdd_HHMMSS'), app.SubID, app.Filestr, app.TrlNum);
            save(fullfile(app.meta_path, metadata_filename), 'meta_data');
            
            % Update UI state
            app.TrlNum = app.TrlNum + 1;
            app.PathStatusLabel.Text = sprintf('Path: %s (Next Trial: %d)', app.pathname, app.TrlNum);
            app.StatusLamp.Color = 'red';
            app.StartButton.Enable = 'on';
            app.StopButton.Enable = 'off';
            app.InitializeButton.Enable = 'on';
        end

        % Button pushed function: SelectPathButton
        function SelectPathButtonPushed(app, event)
            selectedPath = uigetdir(pwd, 'Select Path to Save Data');
            if selectedPath == 0, return; end % User cancelled
            
            app.pathname = selectedPath;
            app.meta_path = fullfile(app.pathname, 'metadata');
            if ~exist(app.meta_path, 'dir'), mkdir(app.meta_path); end
            
            % Logic to find next trial number (assumes a function get_nxt_trialnb exists)
            try
                app.TrlNum = get_nxt_trialnb(app.pathname);
            catch
                app.TrlNum = 1;
            end
            app.PathStatusLabel.Text = sprintf('Path: %s (Next Trial: %d)', app.pathname, app.TrlNum);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1280 720];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIFigureGridLayout
            app.UIFigureGridLayout = uigridlayout(app.UIFigure);
            app.UIFigureGridLayout.ColumnWidth = {'1x'};
            app.UIFigureGridLayout.RowHeight = {'1x', 240};
            app.UIFigureGridLayout.RowSpacing = 0;
            app.UIFigureGridLayout.Padding = [0 0 0 0];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigureGridLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;

            % Create EMGGridLayout
            app.EMGGridLayout = uitab(app.TabGroup);
            app.EMGGridLayout.Title = 'EMG Channels';

            % Create EMGGridLayout_1
            app.EMGGridLayout_1 = uigridlayout(app.EMGGridLayout);
            app.EMGGridLayout_1.ColumnWidth = {'1x', 180};
            app.EMGGridLayout_1.RowHeight = {'1x'};

            % Create EMGGridLayout_2
            app.EMGGridLayout_2 = uigridlayout(app.EMGGridLayout_1);
            app.EMGGridLayout_2.Layout.Row = 1;
            app.EMGGridLayout_2.Layout.Column = 1;

            % Create EMGAxes_1
            app.EMGAxes_1 = uiaxes(app.EMGGridLayout_2);
            title(app.EMGAxes_1, 'EMG CH1')
            xlabel(app.EMGAxes_1, 'Time (s)')
            ylabel(app.EMGAxes_1, 'Amplitude')
            zlabel(app.EMGAxes_1, 'Z')
            app.EMGAxes_1.Layout.Row = 1;
            app.EMGAxes_1.Layout.Column = 1;

            % Create EMGAxes_2
            app.EMGAxes_2 = uiaxes(app.EMGGridLayout_2);
            title(app.EMGAxes_2, 'EMG CH2')
            xlabel(app.EMGAxes_2, 'Time (s)')
            ylabel(app.EMGAxes_2, 'Amplitude')
            zlabel(app.EMGAxes_2, 'Z')
            app.EMGAxes_2.Layout.Row = 1;
            app.EMGAxes_2.Layout.Column = 2;

            % Create EMGAxes_4
            app.EMGAxes_4 = uiaxes(app.EMGGridLayout_2);
            title(app.EMGAxes_4, 'EMG CH4')
            xlabel(app.EMGAxes_4, 'Time (s)')
            ylabel(app.EMGAxes_4, 'Amplitude')
            zlabel(app.EMGAxes_4, 'Z')
            app.EMGAxes_4.Layout.Row = 2;
            app.EMGAxes_4.Layout.Column = 2;

            % Create EMGAxes_3
            app.EMGAxes_3 = uiaxes(app.EMGGridLayout_2);
            title(app.EMGAxes_3, 'EMG CH3')
            xlabel(app.EMGAxes_3, 'Time (s)')
            ylabel(app.EMGAxes_3, 'Amplitude')
            zlabel(app.EMGAxes_3, 'Z')
            app.EMGAxes_3.Layout.Row = 2;
            app.EMGAxes_3.Layout.Column = 1;

            % Create EMGDisplayOptionsPanel
            app.EMGDisplayOptionsPanel = uipanel(app.EMGGridLayout_1);
            app.EMGDisplayOptionsPanel.Title = 'Display Options';
            app.EMGDisplayOptionsPanel.Layout.Row = 1;
            app.EMGDisplayOptionsPanel.Layout.Column = 2;

            % Create EMGDiSplayOptionsGridLayout
            app.EMGDiSplayOptionsGridLayout = uigridlayout(app.EMGDisplayOptionsPanel);
            app.EMGDiSplayOptionsGridLayout.RowHeight = {'6x', '1x', '1x'};

            % Create YmaxLabel_3
            app.YmaxLabel_3 = uilabel(app.EMGDiSplayOptionsGridLayout);
            app.YmaxLabel_3.HorizontalAlignment = 'center';
            app.YmaxLabel_3.FontSize = 18;
            app.YmaxLabel_3.Layout.Row = 2;
            app.YmaxLabel_3.Layout.Column = 1;
            app.YmaxLabel_3.Text = 'Y max';

            % Create EMGYMaxEditField
            app.EMGYMaxEditField = uieditfield(app.EMGDiSplayOptionsGridLayout, 'numeric');
            app.EMGYMaxEditField.FontSize = 18;
            app.EMGYMaxEditField.Layout.Row = 2;
            app.EMGYMaxEditField.Layout.Column = 2;
            app.EMGYMaxEditField.Value = 0.5;

            % Create YminLabel_3
            app.YminLabel_3 = uilabel(app.EMGDiSplayOptionsGridLayout);
            app.YminLabel_3.HorizontalAlignment = 'center';
            app.YminLabel_3.FontSize = 18;
            app.YminLabel_3.Layout.Row = 3;
            app.YminLabel_3.Layout.Column = 1;
            app.YminLabel_3.Text = 'Y min';

            % Create EMGYMinEditField
            app.EMGYMinEditField = uieditfield(app.EMGDiSplayOptionsGridLayout, 'numeric');
            app.EMGYMinEditField.FontSize = 18;
            app.EMGYMinEditField.Layout.Row = 3;
            app.EMGYMinEditField.Layout.Column = 2;
            app.EMGYMinEditField.Value = -0.5;

            % Create EMGChannelsLabel
            app.EMGChannelsLabel = uilabel(app.EMGDiSplayOptionsGridLayout);
            app.EMGChannelsLabel.HorizontalAlignment = 'center';
            app.EMGChannelsLabel.Layout.Row = 1;
            app.EMGChannelsLabel.Layout.Column = 1;
            app.EMGChannelsLabel.Text = {'EMG'; 'Channels'};

            % Create EMGChannelsListBox
            app.EMGChannelsListBox = uilistbox(app.EMGDiSplayOptionsGridLayout);
            app.EMGChannelsListBox.Items = {'1', '2', '3', '4'};
            app.EMGChannelsListBox.Multiselect = 'on';
            app.EMGChannelsListBox.Layout.Row = 1;
            app.EMGChannelsListBox.Layout.Column = 2;
            app.EMGChannelsListBox.Value = {};

            % Create AnalogGridLayout
            app.AnalogGridLayout = uitab(app.TabGroup);
            app.AnalogGridLayout.Title = 'Analog Channels';

            % Create AnalogGridLayout_2
            app.AnalogGridLayout_2 = uigridlayout(app.AnalogGridLayout);
            app.AnalogGridLayout_2.ColumnWidth = {'1x', 180};
            app.AnalogGridLayout_2.RowHeight = {'1x'};

            % Create AnalogGridLayout_3
            app.AnalogGridLayout_3 = uigridlayout(app.AnalogGridLayout_2);
            app.AnalogGridLayout_3.RowHeight = {'1x'};
            app.AnalogGridLayout_3.Layout.Row = 1;
            app.AnalogGridLayout_3.Layout.Column = 1;

            % Create AnalogAxes_1
            app.AnalogAxes_1 = uiaxes(app.AnalogGridLayout_3);
            title(app.AnalogAxes_1, 'Analog CH1')
            xlabel(app.AnalogAxes_1, 'Time (s)')
            ylabel(app.AnalogAxes_1, 'Amplitude')
            zlabel(app.AnalogAxes_1, 'Z')
            app.AnalogAxes_1.Layout.Row = 1;
            app.AnalogAxes_1.Layout.Column = 1;

            % Create AnalogAxes_2
            app.AnalogAxes_2 = uiaxes(app.AnalogGridLayout_3);
            title(app.AnalogAxes_2, 'Analog CH2')
            xlabel(app.AnalogAxes_2, 'Time (s)')
            ylabel(app.AnalogAxes_2, 'Amplitude')
            zlabel(app.AnalogAxes_2, 'Z')
            app.AnalogAxes_2.Layout.Row = 1;
            app.AnalogAxes_2.Layout.Column = 2;

            % Create AnalogDisplayOptionsPanel
            app.AnalogDisplayOptionsPanel = uipanel(app.AnalogGridLayout_2);
            app.AnalogDisplayOptionsPanel.Title = 'Display Options';
            app.AnalogDisplayOptionsPanel.Layout.Row = 1;
            app.AnalogDisplayOptionsPanel.Layout.Column = 2;

            % Create AnalogDisplayOptionsGridLayout
            app.AnalogDisplayOptionsGridLayout = uigridlayout(app.AnalogDisplayOptionsPanel);
            app.AnalogDisplayOptionsGridLayout.RowHeight = {'6x', '1x', '1x'};

            % Create YmaxLabel_2
            app.YmaxLabel_2 = uilabel(app.AnalogDisplayOptionsGridLayout);
            app.YmaxLabel_2.HorizontalAlignment = 'center';
            app.YmaxLabel_2.FontSize = 18;
            app.YmaxLabel_2.Layout.Row = 2;
            app.YmaxLabel_2.Layout.Column = 1;
            app.YmaxLabel_2.Text = 'Y max';

            % Create AnalogYMaxEditField
            app.AnalogYMaxEditField = uieditfield(app.AnalogDisplayOptionsGridLayout, 'numeric');
            app.AnalogYMaxEditField.FontSize = 18;
            app.AnalogYMaxEditField.Layout.Row = 2;
            app.AnalogYMaxEditField.Layout.Column = 2;
            app.AnalogYMaxEditField.Value = 0.5;

            % Create YminLabel_2
            app.YminLabel_2 = uilabel(app.AnalogDisplayOptionsGridLayout);
            app.YminLabel_2.HorizontalAlignment = 'center';
            app.YminLabel_2.FontSize = 18;
            app.YminLabel_2.Layout.Row = 3;
            app.YminLabel_2.Layout.Column = 1;
            app.YminLabel_2.Text = 'Y min';

            % Create AnalogYMinEditField
            app.AnalogYMinEditField = uieditfield(app.AnalogDisplayOptionsGridLayout, 'numeric');
            app.AnalogYMinEditField.FontSize = 18;
            app.AnalogYMinEditField.Layout.Row = 3;
            app.AnalogYMinEditField.Layout.Column = 2;
            app.AnalogYMinEditField.Value = -0.5;

            % Create AnalogChannelLabel
            app.AnalogChannelLabel = uilabel(app.AnalogDisplayOptionsGridLayout);
            app.AnalogChannelLabel.HorizontalAlignment = 'center';
            app.AnalogChannelLabel.Layout.Row = 1;
            app.AnalogChannelLabel.Layout.Column = 1;
            app.AnalogChannelLabel.Text = {'Analog'; 'Channels'};

            % Create AnalogChannelsListBox
            app.AnalogChannelsListBox = uilistbox(app.AnalogDisplayOptionsGridLayout);
            app.AnalogChannelsListBox.Items = {'1', '2', '3', '4'};
            app.AnalogChannelsListBox.Multiselect = 'on';
            app.AnalogChannelsListBox.Layout.Row = 1;
            app.AnalogChannelsListBox.Layout.Column = 2;
            app.AnalogChannelsListBox.Value = {'1'};

            % Create CombinedGridLayout
            app.CombinedGridLayout = uitab(app.TabGroup);
            app.CombinedGridLayout.Title = 'Combined';

            % Create CombinedGridLayout_2
            app.CombinedGridLayout_2 = uigridlayout(app.CombinedGridLayout);
            app.CombinedGridLayout_2.ColumnWidth = {'1x', 180};
            app.CombinedGridLayout_2.RowHeight = {'1x'};

            % Create CombinedAxes
            app.CombinedAxes = uiaxes(app.CombinedGridLayout_2);
            title(app.CombinedAxes, 'Title')
            xlabel(app.CombinedAxes, 'Time (s)')
            ylabel(app.CombinedAxes, 'Amplitude')
            zlabel(app.CombinedAxes, 'Z')
            app.CombinedAxes.Layout.Row = 1;
            app.CombinedAxes.Layout.Column = 1;

            % Create CombinedDisplayOptionsPanel
            app.CombinedDisplayOptionsPanel = uipanel(app.CombinedGridLayout_2);
            app.CombinedDisplayOptionsPanel.Title = 'Display Options';
            app.CombinedDisplayOptionsPanel.Layout.Row = 1;
            app.CombinedDisplayOptionsPanel.Layout.Column = 2;

            % Create CombinedDisplayOptionsGridLayout
            app.CombinedDisplayOptionsGridLayout = uigridlayout(app.CombinedDisplayOptionsPanel);
            app.CombinedDisplayOptionsGridLayout.RowHeight = {'6x', '1x', '1x'};

            % Create CombinedChannelLabel
            app.CombinedChannelLabel = uilabel(app.CombinedDisplayOptionsGridLayout);
            app.CombinedChannelLabel.HorizontalAlignment = 'center';
            app.CombinedChannelLabel.Layout.Row = 1;
            app.CombinedChannelLabel.Layout.Column = 1;
            app.CombinedChannelLabel.Text = 'Combined';

            % Create CombinedListBox
            app.CombinedListBox = uilistbox(app.CombinedDisplayOptionsGridLayout);
            app.CombinedListBox.Items = {'EMG1', 'EMG2', 'EMG3', 'EMG4', 'ANA1', 'ANA2'};
            app.CombinedListBox.Multiselect = 'on';
            app.CombinedListBox.Layout.Row = 1;
            app.CombinedListBox.Layout.Column = 2;
            app.CombinedListBox.Value = {'EMG1'};

            % Create YmaxLabel
            app.YmaxLabel = uilabel(app.CombinedDisplayOptionsGridLayout);
            app.YmaxLabel.HorizontalAlignment = 'center';
            app.YmaxLabel.FontSize = 18;
            app.YmaxLabel.Layout.Row = 2;
            app.YmaxLabel.Layout.Column = 1;
            app.YmaxLabel.Text = 'Y max';

            % Create CombinedYMaxEditField
            app.CombinedYMaxEditField = uieditfield(app.CombinedDisplayOptionsGridLayout, 'numeric');
            app.CombinedYMaxEditField.FontSize = 18;
            app.CombinedYMaxEditField.Layout.Row = 2;
            app.CombinedYMaxEditField.Layout.Column = 2;
            app.CombinedYMaxEditField.Value = 0.5;

            % Create YminLabel
            app.YminLabel = uilabel(app.CombinedDisplayOptionsGridLayout);
            app.YminLabel.HorizontalAlignment = 'center';
            app.YminLabel.FontSize = 18;
            app.YminLabel.Layout.Row = 3;
            app.YminLabel.Layout.Column = 1;
            app.YminLabel.Text = 'Y min';

            % Create CombinedYMinEditField
            app.CombinedYMinEditField = uieditfield(app.CombinedDisplayOptionsGridLayout, 'numeric');
            app.CombinedYMinEditField.FontSize = 18;
            app.CombinedYMinEditField.Layout.Row = 3;
            app.CombinedYMinEditField.Layout.Column = 2;
            app.CombinedYMinEditField.Value = -0.5;

            % Create ControlPanel
            app.ControlPanel = uipanel(app.UIFigureGridLayout);
            app.ControlPanel.Title = 'Experiment Controls';
            app.ControlPanel.Layout.Row = 2;
            app.ControlPanel.Layout.Column = 1;

            % Create ControlGridLayout
            app.ControlGridLayout = uigridlayout(app.ControlPanel);
            app.ControlGridLayout.ColumnWidth = {'1x', '2x', '1.5x'};

            % Create SessionInfoPanel
            app.SessionInfoPanel = uipanel(app.ControlGridLayout);
            app.SessionInfoPanel.Title = 'Session Info';
            app.SessionInfoPanel.Layout.Row = 1;
            app.SessionInfoPanel.Layout.Column = 1;

            % Create SessionInfoGridLayout
            app.SessionInfoGridLayout = uigridlayout(app.SessionInfoPanel);

            % Create SubjectIDLabel
            app.SubjectIDLabel = uilabel(app.SessionInfoGridLayout);
            app.SubjectIDLabel.HorizontalAlignment = 'right';
            app.SubjectIDLabel.Layout.Row = 1;
            app.SubjectIDLabel.Layout.Column = 1;
            app.SubjectIDLabel.Text = 'Subject ID';

            % Create SubjectIDEditField
            app.SubjectIDEditField = uieditfield(app.SessionInfoGridLayout, 'text');
            app.SubjectIDEditField.Layout.Row = 1;
            app.SubjectIDEditField.Layout.Column = 2;

            % Create SessionNameLabel
            app.SessionNameLabel = uilabel(app.SessionInfoGridLayout);
            app.SessionNameLabel.HorizontalAlignment = 'right';
            app.SessionNameLabel.Layout.Row = 2;
            app.SessionNameLabel.Layout.Column = 1;
            app.SessionNameLabel.Text = 'Session Name';

            % Create FileStringEditField
            app.FileStringEditField = uieditfield(app.SessionInfoGridLayout, 'text');
            app.FileStringEditField.Layout.Row = 2;
            app.FileStringEditField.Layout.Column = 2;

            % Create DataPathPanel
            app.DataPathPanel = uipanel(app.ControlGridLayout);
            app.DataPathPanel.Title = 'Data Path';
            app.DataPathPanel.Layout.Row = 2;
            app.DataPathPanel.Layout.Column = 1;

            % Create DataPathGridLayout
            app.DataPathGridLayout = uigridlayout(app.DataPathPanel);
            app.DataPathGridLayout.ColumnWidth = {'1x'};

            % Create SelectPathButton
            app.SelectPathButton = uibutton(app.DataPathGridLayout, 'push');
            app.SelectPathButton.ButtonPushedFcn = createCallbackFcn(app, @SelectPathButtonPushed, true);
            app.SelectPathButton.Layout.Row = 1;
            app.SelectPathButton.Layout.Column = 1;
            app.SelectPathButton.Text = 'Select Path';

            % Create PathStatusLabel
            app.PathStatusLabel = uilabel(app.DataPathGridLayout);
            app.PathStatusLabel.Layout.Row = 2;
            app.PathStatusLabel.Layout.Column = 1;
            app.PathStatusLabel.Text = 'Path:';

            % Create AcquisitionControlPanel
            app.AcquisitionControlPanel = uipanel(app.ControlGridLayout);
            app.AcquisitionControlPanel.Title = 'Acquisition Control';
            app.AcquisitionControlPanel.Layout.Row = [1 2];
            app.AcquisitionControlPanel.Layout.Column = 2;

            % Create AcquisitionControlGridLayout
            app.AcquisitionControlGridLayout = uigridlayout(app.AcquisitionControlPanel);
            app.AcquisitionControlGridLayout.ColumnWidth = {'1x', '1x', '1x'};
            app.AcquisitionControlGridLayout.RowHeight = {'1x', '0.4x'};

            % Create InitializeButton
            app.InitializeButton = uibutton(app.AcquisitionControlGridLayout, 'push');
            app.InitializeButton.ButtonPushedFcn = createCallbackFcn(app, @InitializeButtonPushed, true);
            app.InitializeButton.BackgroundColor = [0.2196 0.4 0.2549];
            app.InitializeButton.FontSize = 32;
            app.InitializeButton.Layout.Row = 1;
            app.InitializeButton.Layout.Column = 1;
            app.InitializeButton.Text = 'Connect';

            % Create StartButton
            app.StartButton = uibutton(app.AcquisitionControlGridLayout, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.BackgroundColor = [0.9765 0.4784 0];
            app.StartButton.FontSize = 32;
            app.StartButton.Layout.Row = 1;
            app.StartButton.Layout.Column = 2;
            app.StartButton.Text = 'Start';

            % Create StopButton
            app.StopButton = uibutton(app.AcquisitionControlGridLayout, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.BackgroundColor = [0.9961 0.8196 0.4157];
            app.StopButton.FontSize = 32;
            app.StopButton.Layout.Row = 1;
            app.StopButton.Layout.Column = 3;
            app.StopButton.Text = 'Stop';

            % Create StatusLamp
            app.StatusLamp = uilamp(app.AcquisitionControlGridLayout);
            app.StatusLamp.Layout.Row = 2;
            app.StatusLamp.Layout.Column = 2;

            % Create StatusLabel
            app.StatusLabel = uilabel(app.AcquisitionControlGridLayout);
            app.StatusLabel.FontSize = 18;
            app.StatusLabel.Layout.Row = 2;
            app.StatusLabel.Layout.Column = 3;
            app.StatusLabel.Text = 'Status';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = DAQ_App_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end