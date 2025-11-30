function kiteLogApp_v3
%KITELOGAPP_V3 UC3M AWE kite log plotting app with histograms & boxplots.

    % Shared state
    dataTable = table();
    meta      = struct();
    ui        = struct();

    createComponents();

    %==================================================================%
    %                         NESTED UI SETUP                          %
    %==================================================================%

    function createComponents()
        % Main figure
        ui.fig = uifigure( ...
            'Name','UC3M AWE Kite Log Plotter', ...
            'Position',[100 100 1200 700], ...
            'Color',[1 1 1]);

        mainGrid = uigridlayout(ui.fig,[3 1]);
        mainGrid.RowHeight   = {80,'1x',22};
        mainGrid.ColumnWidth = {'1x'};

        %---------------- Header ----------------%
        headerGrid = uigridlayout(mainGrid,[1 3]);
        headerGrid.Layout.Row    = 1;
        headerGrid.Layout.Column = 1;
        headerGrid.ColumnWidth   = {120,'1x',120};

        ui.logoLeft = uiimage(headerGrid);
        ui.logoLeft.Layout.Row    = 1;
        ui.logoLeft.Layout.Column = 1;
        ui.logoLeft.ImageSource   = 'AWES_Logo.png';
        ui.logoLeft.ScaleMethod   = 'fit';

        ui.headerLabel = uilabel(headerGrid);
        ui.headerLabel.Layout.Row    = 1;
        ui.headerLabel.Layout.Column = 2;
        ui.headerLabel.Text          = 'UC3M Airborne Wind Energy – Kite Log Plotter';
        ui.headerLabel.FontSize      = 18;
        ui.headerLabel.FontWeight    = 'bold';
        ui.headerLabel.HorizontalAlignment = 'center';

        ui.logoRight = uiimage(headerGrid);
        ui.logoRight.Layout.Row    = 1;
        ui.logoRight.Layout.Column = 3;
        ui.logoRight.ImageSource   = 'logo.jpg';
        ui.logoRight.ScaleMethod   = 'fit';

        %---------------- Body ----------------%
        bodyGrid = uigridlayout(mainGrid,[1 2]);
        bodyGrid.Layout.Row    = 2;
        bodyGrid.Layout.Column = 1;
        bodyGrid.ColumnWidth   = {320,'1x'};

        % Left: tab group
        ui.tabGroup = uitabgroup(bodyGrid);
        ui.tabGroup.Layout.Row    = 1;
        ui.tabGroup.Layout.Column = 1;

        ui.tabPlot   = uitab(ui.tabGroup,'Title','Plot');
        ui.tabFigure = uitab(ui.tabGroup,'Title','Figure');

        %---------------- PLOT TAB ----------------%
        % 11 rows: load, file, plot type, X, Y, layout, grid/legend, buttons
        plotGrid = uigridlayout(ui.tabPlot,[11 2]);
        plotGrid.RowHeight   = {30,30,20,30,20,30,20,'1x',30,30,30};
        plotGrid.ColumnWidth = {110,'1x'};

        % 1) Load button
        ui.loadButton = uibutton(plotGrid, ...
            'Text','Load CSV log...', ...
            'ButtonPushedFcn',@onLoadLog);
        ui.loadButton.Layout.Row    = 1;
        ui.loadButton.Layout.Column = [1 2];

        % 2) File label
        ui.fileLabel = uilabel(plotGrid, ...
            'Text','No file loaded');
        ui.fileLabel.Layout.Row    = 2;
        ui.fileLabel.Layout.Column = [1 2];
        ui.fileLabel.WordWrap      = 'on';

        % 3) Plot kind selector
        ui.plotKindLbl = uilabel(plotGrid, ...
            'Text','Plot type:', ...
            'HorizontalAlignment','right');
        ui.plotKindLbl.Layout.Row    = 3;
        ui.plotKindLbl.Layout.Column = 1;

        ui.plotKindDropDown = uidropdown(plotGrid, ...
            'Items',{'Time series','Histogram','Boxplot'}, ...
            'ItemsData',{'timeseries','histogram','boxplot'}, ...
            'Value','timeseries', ...
            'ValueChangedFcn',@onPlotKindChanged);
        ui.plotKindDropDown.Layout.Row    = 4;
        ui.plotKindDropDown.Layout.Column = 2;

        % 4) X variable
        ui.xLabelLbl = uilabel(plotGrid, ...
            'Text','X variable:', ...
            'HorizontalAlignment','right');
        ui.xLabelLbl.Layout.Row    = 5;
        ui.xLabelLbl.Layout.Column = 1;

        ui.xVarDropDown = uidropdown(plotGrid, ...
            'Items',{}, ...
            'ItemsData',{}, ...
            'ValueChangedFcn',@onXVarChanged);
        ui.xVarDropDown.Layout.Row    = 6;
        ui.xVarDropDown.Layout.Column = 2;

        % 5) Y variables
        ui.yLabelLbl = uilabel(plotGrid, ...
            'Text','Y variable(s):', ...
            'HorizontalAlignment','right');
        ui.yLabelLbl.Layout.Row    = 7;
        ui.yLabelLbl.Layout.Column = 1;

        ui.yVarList = uilistbox(plotGrid, ...
            'Items',{}, ...
            'Multiselect','on', ...
            'ValueChangedFcn',@onYVarChanged);
        ui.yVarList.Layout.Row    = 8;
        ui.yVarList.Layout.Column = 2;

        % 6) Layout (time series only)
        ui.layoutLbl = uilabel(plotGrid, ...
            'Text','Layout:', ...
            'HorizontalAlignment','right');
        ui.layoutLbl.Layout.Row    = 9;
        ui.layoutLbl.Layout.Column = 1;

        ui.layoutDropDown = uidropdown(plotGrid, ...
            'Items',{'Single axes','Stacked axes'}, ...
            'ItemsData',{'single','stacked'}, ...
            'Value','stacked');
        ui.layoutDropDown.Layout.Row    = 9;
        ui.layoutDropDown.Layout.Column = 2;

        % 7) Grid / legend
        ui.gridCheck = uicheckbox(plotGrid, ...
            'Text','Show grid', ...
            'Value',true);
        ui.gridCheck.Layout.Row    = 10;
        ui.gridCheck.Layout.Column = 1;

        ui.legendCheck = uicheckbox(plotGrid, ...
            'Text','Show legend', ...
            'Value',true);
        ui.legendCheck.Layout.Row    = 10;
        ui.legendCheck.Layout.Column = 2;

        % 8) Plot & export
        ui.plotButton = uibutton(plotGrid, ...
            'Text','Plot', ...
            'ButtonPushedFcn',@onPlotPressed);
        ui.plotButton.Layout.Row    = 11;
        ui.plotButton.Layout.Column = 1;

        ui.exportButton = uibutton(plotGrid, ...
            'Text','Export PNG...', ...
            'ButtonPushedFcn',@onExportPressed, ...
            'Enable','off');
        ui.exportButton.Layout.Row    = 11;
        ui.exportButton.Layout.Column = 2;

        %---------------- FIGURE TAB ----------------%
        figGrid = uigridlayout(ui.tabFigure,[12 2]);
        figGrid.RowHeight   = {20,30,20,30,20,30,30,30,30,30,30,30};
        figGrid.ColumnWidth = {130,'1x'};

        ui.titleLbl = uilabel(figGrid, ...
            'Text','Title:', ...
            'HorizontalAlignment','right');
        ui.titleLbl.Layout.Row    = 1;
        ui.titleLbl.Layout.Column = 1;

        ui.titleEdit = uieditfield(figGrid,'text', ...
            'Value','', ...
            'ValueChangedFcn',@onLabelEdited);
        ui.titleEdit.Layout.Row    = 2;
        ui.titleEdit.Layout.Column = 2;

        ui.xAxisLbl = uilabel(figGrid, ...
            'Text','X label:', ...
            'HorizontalAlignment','right');
        ui.xAxisLbl.Layout.Row    = 3;
        ui.xAxisLbl.Layout.Column = 1;

        ui.xAxisEdit = uieditfield(figGrid,'text', ...
            'Value','', ...
            'ValueChangedFcn',@onLabelEdited);
        ui.xAxisEdit.Layout.Row    = 4;
        ui.xAxisEdit.Layout.Column = 2;

        ui.yAxisLbl = uilabel(figGrid, ...
            'Text','Y label (single axes / boxplot):', ...
            'HorizontalAlignment','right');
        ui.yAxisLbl.Layout.Row    = 5;
        ui.yAxisLbl.Layout.Column = 1;

        ui.yAxisEdit = uieditfield(figGrid,'text', ...
            'Value','', ...
            'ValueChangedFcn',@onLabelEdited);
        ui.yAxisEdit.Layout.Row    = 6;
        ui.yAxisEdit.Layout.Column = 2;

        ui.titleSizeLbl = uilabel(figGrid, ...
            'Text','Title size:', ...
            'HorizontalAlignment','right');
        ui.titleSizeLbl.Layout.Row    = 7;
        ui.titleSizeLbl.Layout.Column = 1;

        ui.titleSizeSpinner = uispinner(figGrid, ...
            'Limits',[6 40], ...
            'Value',14);
        ui.titleSizeSpinner.Layout.Row    = 7;
        ui.titleSizeSpinner.Layout.Column = 2;

        ui.labelSizeLbl = uilabel(figGrid, ...
            'Text','Label size:', ...
            'HorizontalAlignment','right');
        ui.labelSizeLbl.Layout.Row    = 8;
        ui.labelSizeLbl.Layout.Column = 1;

        ui.labelSizeSpinner = uispinner(figGrid, ...
            'Limits',[6 40], ...
            'Value',12);
        ui.labelSizeSpinner.Layout.Row    = 8;
        ui.labelSizeSpinner.Layout.Column = 2;

        ui.tickSizeLbl = uilabel(figGrid, ...
            'Text','Tick size:', ...
            'HorizontalAlignment','right');
        ui.tickSizeLbl.Layout.Row    = 9;
        ui.tickSizeLbl.Layout.Column = 1;

        ui.tickSizeSpinner = uispinner(figGrid, ...
            'Limits',[6 40], ...
            'Value',11);
        ui.tickSizeSpinner.Layout.Row    = 9;
        ui.tickSizeSpinner.Layout.Column = 2;

        ui.legendSizeLbl = uilabel(figGrid, ...
            'Text','Legend size:', ...
            'HorizontalAlignment','right');
        ui.legendSizeLbl.Layout.Row    = 10;
        ui.legendSizeLbl.Layout.Column = 1;

        ui.legendSizeSpinner = uispinner(figGrid, ...
            'Limits',[6 40], ...
            'Value',10);
        ui.legendSizeSpinner.Layout.Row    = 10;
        ui.legendSizeSpinner.Layout.Column = 2;

        ui.colorLbl = uilabel(figGrid, ...
            'Text','Color scheme:', ...
            'HorizontalAlignment','right');
        ui.colorLbl.Layout.Row    = 11;
        ui.colorLbl.Layout.Column = 1;

        ui.colorDropDown = uidropdown(figGrid, ...
            'Items',{'Default','Lines','Parula','Turbo','Gray'}, ...
            'Value','Default');
        ui.colorDropDown.Layout.Row    = 11;
        ui.colorDropDown.Layout.Column = 2;

        ui.plotStyleLbl = uilabel(figGrid, ...
            'Text','Plot style (time series):', ...
            'HorizontalAlignment','right');
        ui.plotStyleLbl.Layout.Row    = 12;
        ui.plotStyleLbl.Layout.Column = 1;

        ui.plotStyleDropDown = uidropdown(figGrid, ...
            'Items',{'Line','Line with markers','Scatter'}, ...
            'Value','Line');
        ui.plotStyleDropDown.Layout.Row    = 12;
        ui.plotStyleDropDown.Layout.Column = 2;

        %---------------- Plot panel on the right ----------------%
        ui.plotPanel = uipanel(bodyGrid);
        ui.plotPanel.Layout.Row    = 1;
        ui.plotPanel.Layout.Column = 2;
        ui.plotPanel.Title         = 'Plot';

        ui.plotGrid = uigridlayout(ui.plotPanel,[1 1]);
        ui.plotGrid.RowHeight   = {'1x'};
        ui.plotGrid.ColumnWidth = {'1x'};

        ax0 = uiaxes(ui.plotGrid);
        ax0.Layout.Row    = 1;
        ax0.Layout.Column = 1;
        ax0.XGrid         = 'on';
        ax0.YGrid         = 'on';
        ax0.Box           = 'on';
        ax0.FontName      = 'Times New Roman';
        ax0.FontSize      = 11;
        title(ax0,'No data loaded','Interpreter','latex');

        % Status bar
        ui.statusLabel = uilabel(mainGrid, ...
            'Text','Ready. Load a CSV log to start.', ...
            'HorizontalAlignment','left');
        ui.statusLabel.Layout.Row    = 3;
        ui.statusLabel.Layout.Column = 1;
    end

    %==================================================================%
    %                           CALLBACKS                              %
    %==================================================================%

    function figSettings = getFigureSettings()
        figSettings = struct();
        figSettings.TitleFontSize  = ui.titleSizeSpinner.Value;
        figSettings.LabelFontSize  = ui.labelSizeSpinner.Value;
        figSettings.TickFontSize   = ui.tickSizeSpinner.Value;
        figSettings.LegendFontSize = ui.legendSizeSpinner.Value;
        rawColor                   = ui.colorDropDown.Value;
        figSettings.ColorScheme    = lower(strrep(rawColor,' ',''));
        figSettings.PlotStyle      = mapPlotStyle(ui.plotStyleDropDown.Value);
        figSettings.FontName       = 'Times New Roman';
    end

    function onPlotKindChanged(src,~)
        kind   = src.Value;                 % 'timeseries' | 'histogram' | 'boxplot'
        isTime = strcmp(kind,'timeseries');

        if isTime
            ui.xLabelLbl.Enable     = 'on';
            ui.xVarDropDown.Enable  = 'on';
            ui.layoutLbl.Enable     = 'on';
            ui.layoutDropDown.Enable = 'on';
        else
            ui.xLabelLbl.Enable     = 'off';
            ui.xVarDropDown.Enable  = 'off';
            ui.layoutLbl.Enable     = 'off';
            ui.layoutDropDown.Enable = 'off';

            % Sensible default layouts for non-time-series
            if strcmp(kind,'histogram')
                ui.layoutDropDown.Value = 'stacked';
            else % boxplot
                ui.layoutDropDown.Value = 'single';
            end
        end
    end

    function onLoadLog(~,~)
        [fileName,pathName] = uigetfile('*.csv','Select kite log CSV file');
        if isequal(fileName,0)
            return;
        end
        fullName = fullfile(pathName,fileName);

        try
            [dataTable, meta] = readKiteLog(fullName);
        catch ME
            uialert(ui.fig, ...
                sprintf('Error reading log file:\n\n%s',ME.message), ...
                'Read error');
            return;
        end

        varNames = string(dataTable.Properties.VariableNames);

        % X candidates
        ui.xVarDropDown.Items     = cellstr(varNames);
        ui.xVarDropDown.ItemsData = cellstr(varNames);

        % Y candidates: numeric vars
        numericMask = varfun(@isnumeric,dataTable,'OutputFormat','uniform');
        yNames      = varNames(numericMask);
        ui.yVarList.Items = cellstr(yNames);
        if ~isempty(yNames)
            nDefault = min(3,numel(yNames));
            ui.yVarList.Value = cellstr(yNames(1:nDefault));
        else
            ui.yVarList.Value = {};
        end

        % Default X: Time_s if available
        if isfield(meta,'defaultXVar') && any(varNames == meta.defaultXVar)
            ui.xVarDropDown.Value = meta.defaultXVar;
        else
            ui.xVarDropDown.Value = varNames(1);
        end

        xVar  = ui.xVarDropDown.Value;
        yVars = ui.yVarList.Value;
        [defaultTitle,defaultXLabel,defaultYLabel] = defaultLabels(meta,xVar,yVars);
        ui.titleEdit.Value = defaultTitle;
        ui.xAxisEdit.Value = defaultXLabel;
        ui.yAxisEdit.Value = defaultYLabel;

        ui.fileLabel.Text   = sprintf('File: %s',fileName);
        ui.statusLabel.Text = sprintf('Loaded %s (%d samples, %d variables).', ...
            fileName,height(dataTable),width(dataTable));

        delete(ui.plotGrid.Children);
        ax = uiaxes(ui.plotGrid);
        ax.Layout.Row    = 1;
        ax.Layout.Column = 1;
        ax.XGrid         = 'on';
        ax.YGrid         = 'on';
        ax.Box           = 'on';
        ax.FontName      = 'Times New Roman';
        ax.FontSize      = 11;
        title(ax,'Press "Plot" to visualize data','Interpreter','latex');

        ui.exportButton.Enable = 'off';
    end

    function onXVarChanged(~,~)
        if isempty(dataTable)
            return;
        end
        xVar  = ui.xVarDropDown.Value;
        yVars = ui.yVarList.Value;
        [~,defaultXLabel,defaultYLabel] = defaultLabels(meta,xVar,yVars);
        if isempty(strtrim(ui.xAxisEdit.Value))
            ui.xAxisEdit.Value = defaultXLabel;
        end
        if isempty(strtrim(ui.yAxisEdit.Value))
            ui.yAxisEdit.Value = defaultYLabel;
        end
    end

    function onYVarChanged(~,~)
        if isempty(dataTable)
            return;
        end
        xVar  = ui.xVarDropDown.Value;
        yVars = ui.yVarList.Value;
        [~,~,defaultYLabel] = defaultLabels(meta,xVar,yVars);
        if isempty(strtrim(ui.yAxisEdit.Value))
            ui.yAxisEdit.Value = defaultYLabel;
        end
    end

    function onLabelEdited(~,~)
        % placeholder (user overrides already stored in edit fields)
    end

    function onPlotPressed(~,~)
        if isempty(dataTable)
            uialert(ui.fig,'Please load a CSV log first.','No data');
            return;
        end

        xVar  = ui.xVarDropDown.Value;
        yVars = ui.yVarList.Value;
        if isempty(yVars)
            uialert(ui.fig,'Select at least one Y variable to plot.','No Y variable');
            return;
        end

        labels.Title  = ui.titleEdit.Value;
        labels.XLabel = ui.xAxisEdit.Value;
        labels.YLabel = ui.yAxisEdit.Value;

        plotOpts.ShowGrid   = logical(ui.gridCheck.Value);
        plotOpts.ShowLegend = logical(ui.legendCheck.Value);
        plotOpts.Layout     = ui.layoutDropDown.Value;           % 'single' / 'stacked'
        plotOpts.PlotKind   = ui.plotKindDropDown.Value;         % 'timeseries' / 'histogram' / 'boxplot'

        figSettings = getFigureSettings();

        plotLogData(ui.plotGrid,dataTable,xVar,yVars,labels,plotOpts,figSettings);

        ui.statusLabel.Text = sprintf('%s plot of %d variable(s).', ...
            upper(plotOpts.PlotKind(1)), numel(yVars));
        ui.exportButton.Enable = 'on';
    end

    function onExportPressed(~,~)
        if isempty(dataTable)
            uialert(ui.fig,'Nothing to export. Load data and create a plot first.','No data');
            return;
        end

        [fileName,pathName] = uiputfile('*.png','Export plot as PNG');
        if isequal(fileName,0)
            return;
        end
        fullName = fullfile(pathName,fileName);

        try
            exportgraphics(ui.plotPanel,fullName, ...
                'Resolution',300, ...
                'BackgroundColor','white');
        catch ME
            uialert(ui.fig, ...
                sprintf('Error exporting PNG:\n\n%s',ME.message), ...
                'Export error');
            return;
        end

        ui.statusLabel.Text = sprintf('Exported plot panel to %s.',fullName);
    end
end

%=========================================================================%
%                         LOCAL FUNCTIONS                                 %
%=========================================================================%

function [tbl, meta] = readKiteLog(filename)
%READKITELOG  Read kite log CSV and assign fixed channel names.
%
%   CSV has NO header row; columns are:
%     col 1 -> CONTROL_timestamp_us
%     col 2 -> PX_time_boot_ms
%     ...
%   This matches your original code. A derived Time_s (s from start)
%   is added for plotting.

    % Fixed list of names (exactly as in your original code)
    varNames = { ...
        'CONTROL_timestamp_us'
        'PX_time_boot_ms'
        'PX_time_unix_usec'
        'PX_pos_time_boot_ms'
        'Extracol'
        'PX_x'
        'PX_y'
        'PX_z'
        'PX_vx'
        'PX_vy'
        'PX_vz'
        'PX_att_time_boot_ms'
        'PX_qw'
        'PX_qx'
        'PX_qy'
        'PX_qz'
        'PX_rollspeed'
        'PX_pitchspeed'
        'PX_yawspeed'
        'PX_GPS_time_unix_usec'
        'PX_GPS_latitude'
        'PX_GPS_longitude'
        'PX_GPS_altMSL'
        'PX_GPS_cog'
        'PX_fixType'
        'PX_GPS_hacc'
        'PX_GPS_vacc'
        'PX_voltage_battery'
        'PX_battery_remaining'
        'PX_drop_rate_comm'
        'ADC_AIR_us'
        'ADC_AIR_LC1'
        'ADC_AIR_LC2'
        'ADC_AIR_LC3'
        'ADC_LC_1'
        'ADC_LC_2'
        'ADC_LC_3'
        'ADC_LC_left'
        'ADC_LC_center'
        'ADC_LC_right'
        'ENCODER_H'
        'ENCODER_V'
        'WIND_time_boot_ms'
        'WIND_speed'
        'WIND_direction'
        'GPS_meanAccuracy'
        'GPS_duration'
        'GPS_flags'
        'DPRO_voltage_48'
        'DPRO_10_position'
        'DPRO_10_velocity'
        'DPRO_20_position'
        'DPRO_20_velocity'
        'DPRO_21_position'
        'DPRO_21_velocity'
        'DPRO_30_position'
        'DPRO_30_velocity'
        'DPRO_10_current'
        'DPRO_20_current'
        'DPRO_21_current'
        'DPRO_30_current'
        'WINCH_speed'
        'ADC_X'
        'ADC_Y'
        'ADC_T'
        'ADC_K'
        'PIN_1'
        'PIN_2'
        'PIN_up'
        'PIN_down'
        'CONTROL_launch_px2gcu_coordinates_x'
        'CONTROL_launch_px2gcu_coordinates_y'
        'CONTROL_launch_px2gcu_coordinates_z'
        'CONTROL_launch_px_coordinates_x'
        'CONTROL_launch_px_coordinates_y'
        'CONTROL_launch_px_coordinates_z'
        'CONTROL_phi'
        'CONTROL_beta'
        'CONTROL_psi'
        'CONTROL_psi_set'
        'CONTROL_PID_kp'
        'CONTROL_PID_ki'
        'CONTROL_PID_kd'
        'CONTROL_PID_e_k'
        'CONTROL_PID_e_i'
        'CONTROL_PID_e_d'
        'CONTROL_deltaL'
        'CONTROL_thirdLineDeltaL'
        'CONTROL_guidanceMode'
        'CONTROL_foeState'
        'CONTROL_tetherLength'
        'CONTROL_beta_set'
        'CONTROL_PID_pitch_kp'
        'CONTROL_PID_pitch_ki'
        'CONTROL_PID_pitch_kd'
        'CONTROL_PID_pitch_e_k'
        'CONTROL_PID_pitch_e_i'
        'CONTROL_PID_pitch_e_d'};

    % Read file as numeric matrix (no headers), exactly like original
    raw = readmatrix(filename, ...
        'FileType','text', ...
        'Delimiter',',', ...
        'Range','B1');   % <-- key fix: skip column 1 (text)
    nCols = size(raw, 2);

    % Adjust list of names to the real number of columns (original logic)
    if nCols > numel(varNames)
        for i = numel(varNames)+1:nCols
            varNames{end+1} = sprintf('extra_col_%d', i);
        end
    elseif nCols < numel(varNames)
        varNames = varNames(1:nCols);
    end

    % Create table with those names
    tbl = array2table(raw, 'VariableNames', varNames);

    % Derived time in seconds from CONTROL_timestamp_us
    if ismember('CONTROL_timestamp_us', varNames)
        t0         = tbl.CONTROL_timestamp_us(1);
        tbl.Time_s = (tbl.CONTROL_timestamp_us - t0) * 1e-6;  % µs -> s
    else
        tbl.Time_s = (0:height(tbl)-1).';  % fallback
    end

    % Adjust variable names to correct the discrepancy
    if height(tbl) > 0
        tbl.Properties.VariableNames = circshift(tbl.Properties.VariableNames, -1);
    end

    % Metadata for the app
    meta = struct();
    meta.file            = filename;
    meta.timeStampName   = 'CONTROL_timestamp_us';
    meta.timeSecondsName = 'Time_s';
    meta.defaultXVar     = 'Time_s';
    meta.variableNames   = tbl.Properties.VariableNames;

end




%-------------------------------------------------------------------------%

function plotLogData(plotGrid,tbl,xVar,yVars,labels,plotOpts,figSettings)
% Dispatch to the appropriate plot type.

    switch plotOpts.PlotKind
        case 'histogram'
            plotHistogramGrid(plotGrid,tbl,yVars,labels,plotOpts,figSettings);
        case 'boxplot'
            plotBoxplotGrid(plotGrid,tbl,yVars,labels,plotOpts,figSettings);
        otherwise % 'timeseries'
            plotTimeSeriesGrid(plotGrid,tbl,xVar,yVars,labels,plotOpts,figSettings);
    end
end

%-------------------------------------------------------------------------%

function plotTimeSeriesGrid(plotGrid,tbl,xVar,yVars,labels,plotOpts,figSettings)
%TIME SERIES plotting (single or stacked axes).

    if isstring(yVars)
        yVars = cellstr(yVars);
    elseif ischar(yVars)
        yVars = {yVars};
    end
    nY = numel(yVars);

    delete(plotGrid.Children);

    if strcmp(plotOpts.Layout,'single') || nY == 1
        plotGrid.RowHeight   = {'1x'};
        plotGrid.ColumnWidth = {'1x'};
        ax = uiaxes(plotGrid);
        ax.Layout.Row    = 1;
        ax.Layout.Column = 1;
        plotSingleAxes(ax,tbl,xVar,yVars,labels,plotOpts,figSettings);
    else
        plotGrid.RowHeight   = repmat({'1x'},1,nY);
        plotGrid.ColumnWidth = {'1x'};
        for k = 1:nY
            ax = uiaxes(plotGrid);
            ax.Layout.Row    = k;
            ax.Layout.Column = 1;

            localLabels = labels;
            if k ~= 1
                localLabels.Title = '';
            end
            if k ~= nY
                localLabels.XLabel = '';
            end
            localLabels.YLabel = '';

            plotSingleAxes(ax,tbl,xVar,yVars(k),localLabels,plotOpts,figSettings);
        end
    end
end

%-------------------------------------------------------------------------%

function plotHistogramGrid(plotGrid,tbl,yVars,labels,plotOpts,figSettings)
%HISTOGRAMGRID  Distribution plots with stacked subfigures.

    if isstring(yVars)
        yVars = cellstr(yVars);
    elseif ischar(yVars)
        yVars = {yVars};
    end
    nY = numel(yVars);

    delete(plotGrid.Children);
    plotGrid.RowHeight   = repmat({'1x'},1,nY);
    plotGrid.ColumnWidth = {'1x'};

    colors = chooseColorScheme(figSettings.ColorScheme,1); % same color for all

    for k = 1:nY
        ax = uiaxes(plotGrid);
        ax.Layout.Row    = k;
        ax.Layout.Column = 1;

        ax.FontName = figSettings.FontName;
        ax.FontSize = figSettings.TickFontSize;
        box(ax,'on');
        if plotOpts.ShowGrid
            grid(ax,'on');
        else
            grid(ax,'off');
        end

        data = tbl.(yVars{k});
        data = data(~isnan(data));

        h = histogram(ax,data);
        h.FaceColor = colors(1,:);
        h.EdgeColor = 'none';

        if k == 1 && ~isempty(strtrim(labels.Title))
            title(ax,labels.Title,'Interpreter','latex');
            ax.Title.FontSize = figSettings.TitleFontSize;
        else
            title(ax,'','Interpreter','latex');
        end

        % X label = variable name (or user override)
        if ~isempty(strtrim(labels.XLabel))
            xlabel(ax,labels.XLabel,'Interpreter','latex');
        else
            xlabel(ax,yVars{k},'Interpreter','latex');
        end
        ax.XLabel.FontSize = figSettings.LabelFontSize;

        ylabel(ax,'Counts','Interpreter','latex');
        ax.YLabel.FontSize = figSettings.LabelFontSize;
    end
end

%-------------------------------------------------------------------------%

function plotBoxplotGrid(plotGrid,tbl,yVars,labels,plotOpts,figSettings)
%BOXPLOTGRID  Boxplot comparison (one axes) + jittered scatter.

    if isstring(yVars)
        yVars = cellstr(yVars);
    elseif ischar(yVars)
        yVars = {yVars};
    end
    nY = numel(yVars);

    delete(plotGrid.Children);
    plotGrid.RowHeight   = {'1x'};
    plotGrid.ColumnWidth = {'1x'};

    ax = uiaxes(plotGrid);
    ax.Layout.Row    = 1;
    ax.Layout.Column = 1;
    ax.FontName      = figSettings.FontName;
    ax.FontSize      = figSettings.TickFontSize;
    box(ax,'on');

    if plotOpts.ShowGrid
        grid(ax,'on');
    else
        grid(ax,'off');
    end

    % Collect data and group indices
    allData = [];
    grpIdx  = [];
    for k = 1:nY
        y = tbl.(yVars{k});
        y = y(~isnan(y));
        allData = [allData; y(:)];
        grpIdx  = [grpIdx; k*ones(numel(y),1)];
    end

    groupCat = categorical(grpIdx,1:nY,yVars);

    % Boxplot
    boxchart(ax,groupCat,allData);
    ax.XTickLabelRotation = 0;

    % Jittered scatter (red crosses, like your figure)
    hold(ax,'on');
    for k = 1:nY
        y = tbl.(yVars{k});
        y = y(~isnan(y));
        xj = k + (rand(size(y))-0.5)*0.15;
        scatter(ax,xj,y,6,'r','x','MarkerEdgeAlpha',0.4);
    end
    hold(ax,'off');

    % Labels
    if ~isempty(strtrim(labels.Title))
        title(ax,labels.Title,'Interpreter','latex');
        ax.Title.FontSize = figSettings.TitleFontSize;
    else
        title(ax,'','Interpreter','latex');
    end

    if ~isempty(strtrim(labels.XLabel))
        xlabel(ax,labels.XLabel,'Interpreter','latex');
    end
    ax.XLabel.FontSize = figSettings.LabelFontSize;

    if ~isempty(strtrim(labels.YLabel))
        ylabel(ax,labels.YLabel,'Interpreter','latex');
    else
        ylabel(ax,'Value','Interpreter','latex');
    end
    ax.YLabel.FontSize = figSettings.LabelFontSize;

    % Legend off by default (boxchart + scatter are self-explanatory)
    legend(ax,'off');
end

%-------------------------------------------------------------------------%

function plotSingleAxes(ax,tbl,xVar,yVars,labels,plotOpts,figSettings)
%PLOTSINGLEAXES  Low-level time-series plotting on one axes.

    x = tbl.(xVar);

    if isstring(yVars)
        yVars = cellstr(yVars);
    elseif ischar(yVars)
        yVars = {yVars};
    end

    nCurves = numel(yVars);

    ax.FontName = figSettings.FontName;
    ax.FontSize = figSettings.TickFontSize;
    box(ax,'on');

    colors = chooseColorScheme(figSettings.ColorScheme,nCurves);
    colororder(ax,colors);

    hold(ax,'on');
    for k = 1:nCurves
        y = tbl.(yVars{k});
        switch figSettings.PlotStyle
            case 'linemarker'
                p = plot(ax,x,y,'DisplayName',yVars{k});
                p.Marker    = '.';
                p.LineWidth = 1.2;
            case 'scatter'
                scatter(ax,x,y,6,'DisplayName',yVars{k},'Marker','.');
            otherwise % 'line'
                p = plot(ax,x,y,'DisplayName',yVars{k});
                p.LineWidth = 1.2;
        end
    end
    hold(ax,'off');

    if plotOpts.ShowGrid
        grid(ax,'on');
    else
        grid(ax,'off');
    end

    if plotOpts.ShowLegend
        lg = legend(ax,'show','Interpreter','latex','Location','best');
        if ~isempty(lg) && isvalid(lg)
            lg.FontSize = figSettings.LegendFontSize;
        end
    else
        legend(ax,'off');
    end

    if ~isempty(strtrim(labels.Title))
        title(ax,labels.Title,'Interpreter','latex');
        ax.Title.FontSize = figSettings.TitleFontSize;
    else
        title(ax,'','Interpreter','latex');
    end

    if ~isempty(strtrim(labels.XLabel))
        xlabel(ax,labels.XLabel,'Interpreter','latex');
    else
        xlabel(ax,xVar,'Interpreter','latex');
    end
    ax.XLabel.FontSize = figSettings.LabelFontSize;

    if ~isempty(strtrim(labels.YLabel))
        ylabel(ax,labels.YLabel,'Interpreter','latex');
    else
        if numel(yVars) == 1
            ylabel(ax,yVars{1},'Interpreter','latex');
        else
            ylabel(ax,'Signals','Interpreter','latex');
        end
    end
    ax.YLabel.FontSize = figSettings.LabelFontSize;

    if isa(x,'datetime')
        ax.XTickLabelRotation = 30;
    else
        ax.XTickLabelRotation = 0;
    end
end

%-------------------------------------------------------------------------%

function colors = chooseColorScheme(schemeName,n)
    schemeName = lower(strtrim(schemeName));
    switch schemeName
        case 'parula'
            cmap = parula(max(n,7));
        case 'turbo'
            cmap = turbo(max(n,7));
        case 'gray'
            cmap = gray(max(n,7));
        case 'lines'
            cmap = lines(max(n,7));
        otherwise  % 'default'
            base = get(groot,'defaultAxesColorOrder');
            if isempty(base)
                base = lines(7);
            end
            reps = ceil(n/size(base,1));
            cmap = repmat(base,reps,1);
    end
    colors = cmap(1:n,:);
end

%-------------------------------------------------------------------------%

function plotStyle = mapPlotStyle(raw)
    s = lower(strtrim(raw));
    switch s
        case 'line'
            plotStyle = 'line';
        case 'line with markers'
            plotStyle = 'linemarker';
        case 'scatter'
            plotStyle = 'scatter';
        otherwise
            plotStyle = 'line';
    end
end

%-------------------------------------------------------------------------%

function [titleStr,xLabelStr,yLabelStr] = defaultLabels(meta,xVar,yVars)

    if iscell(xVar); xVar = xVar{1}; end
    if isstring(xVar); xVar = char(xVar); end

    if isfield(meta,'file') && ~isempty(meta.file)
        [~,baseName,ext] = fileparts(meta.file);
        filePart = [baseName ext];
        titleStr = sprintf('Log: %s',filePart);
    else
        titleStr = '';
    end

    if isfield(meta,'timeSecondsName') && strcmp(xVar,meta.timeSecondsName)
        xLabelStr = 'Time $t$ [s]';
    elseif isfield(meta,'timeStampName') && strcmp(xVar,meta.timeStampName)
        xLabelStr = 'Time stamp';
    else
        xLabelStr = xVar;
    end

    if isstring(yVars); yVars = cellstr(yVars); end
    if ischar(yVars);   yVars = {yVars};       end

    if isempty(yVars)
        yLabelStr = '';
    elseif numel(yVars) == 1
        yLabelStr = yVars{1};
    else
        yLabelStr = 'Signals';
    end
end
