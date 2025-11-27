function kiteLogApp
%KITELOGAPP UC3M AWE kite log plotting app.
%
%   Run this function with:
%       kiteLogApp
%
%   Features:
%     - Load CSV time series logs (no header, timestamp in column 1).
%     - Automatically parse timestamps, create a relative time vector in seconds.
%     - Choose X variable and one or more Y variables.
%     - Plot multiple channels on the same axes.
%     - LaTeX interpreter for title and axis labels.
%     - Export the current axes as a publication‑quality PNG.
%     - Simple, extendable, programmatic UI layout.

    % Shared application state (available to all nested functions)
    dataTable = table();      % Loaded data
    meta      = struct();     % Metadata about current log
    ui        = struct();     % Handles to UI components

    % Create all UI components
    createComponents();

    %---------------------- nested helper functions ----------------------%

    function createComponents()
        % Main figure
        ui.fig = uifigure( ...
            'Name','UC3M AWE Kite Log Plotter', ...
            'Position',[100 100 1200 700], ...
            'Color',[1 1 1]);

        % Top-level grid: header, body, status bar
        mainGrid = uigridlayout(ui.fig,[3 1]);
        mainGrid.RowHeight   = {80,'1x',22};
        mainGrid.ColumnWidth = {'1x'};

        %---------------- Header with logos ----------------%
        headerGrid = uigridlayout(mainGrid,[1 3]);
        headerGrid.Layout.Row    = 1;
        headerGrid.Layout.Column = 1;
        headerGrid.ColumnWidth   = {120,'1x',120};

        % Left logo (AWES)
        ui.logoLeft = uiimage(headerGrid);
        ui.logoLeft.Layout.Row    = 1;
        ui.logoLeft.Layout.Column = 1;
        ui.logoLeft.ImageSource   = 'AWES_Logo.png';  % ensure this file is on path
        ui.logoLeft.ScaleMethod   = 'fit';

        % Center title
        ui.headerLabel = uilabel(headerGrid);
        ui.headerLabel.Layout.Row    = 1;
        ui.headerLabel.Layout.Column = 2;
        ui.headerLabel.Text          = 'UC3M Airborne Wind Energy – Kite Log Plotter';
        ui.headerLabel.FontSize      = 18;
        ui.headerLabel.FontWeight    = 'bold';
        ui.headerLabel.HorizontalAlignment = 'center';

        % Right logo (UC3M)
        ui.logoRight = uiimage(headerGrid);
        ui.logoRight.Layout.Row    = 1;
        ui.logoRight.Layout.Column = 3;
        ui.logoRight.ImageSource   = 'logo.jpg';      % ensure this file is on path
        ui.logoRight.ScaleMethod   = 'fit';

        %---------------- Body: control panel + plot ----------------%
        bodyGrid = uigridlayout(mainGrid,[1 2]);
        bodyGrid.Layout.Row    = 2;
        bodyGrid.Layout.Column = 1;
        bodyGrid.ColumnWidth   = {320,'1x'};

        % Control panel (left)
        controlPanel = uipanel(bodyGrid);
        controlPanel.Title                = 'Controls';
        controlPanel.Layout.Row           = 1;
        controlPanel.Layout.Column        = 1;
        controlPanel.FontWeight           = 'bold';

        ctrlGrid = uigridlayout(controlPanel,[10 2]);
        ctrlGrid.RowHeight   = {30,30,'1x',30,30,30,30,30,30,30};
        ctrlGrid.ColumnWidth = {90,'1x'};

        % 1) Load button (row 1, spans two columns)
        ui.loadButton = uibutton(ctrlGrid, ...
            'Text','Load CSV log...', ...
            'ButtonPushedFcn',@onLoadLog);
        ui.loadButton.Layout.Row    = 1;
        ui.loadButton.Layout.Column = [1 2];

        % 2) File label (row 2)
        ui.fileLabel = uilabel(ctrlGrid, ...
            'Text','No file loaded');
        ui.fileLabel.Layout.Row       = 2;
        ui.fileLabel.Layout.Column    = [1 2];
        ui.fileLabel.WordWrap         = 'on';

        % 3) X variable selector (row 3)
        ui.xLabelLbl = uilabel(ctrlGrid, ...
            'Text','X variable:', ...
            'HorizontalAlignment','right');
        ui.xLabelLbl.Layout.Row    = 4;
        ui.xLabelLbl.Layout.Column = 1;

        ui.xVarDropDown = uidropdown(ctrlGrid, ...
            'Items',{}, ...
            'ItemsData',{}, ...
            'ValueChangedFcn',@onXVarChanged);
        ui.xVarDropDown.Layout.Row    = 4;
        ui.xVarDropDown.Layout.Column = 2;

        % 4) Y variable list (row 3 is "1x" height)
        ui.yLabelLbl = uilabel(ctrlGrid, ...
            'Text','Y variable(s):', ...
            'HorizontalAlignment','right');
        ui.yLabelLbl.Layout.Row    = 3;
        ui.yLabelLbl.Layout.Column = 1;

        ui.yVarList = uilistbox(ctrlGrid, ...
            'Items',{}, ...
            'Multiselect','on', ...
            'ValueChangedFcn',@onYVarChanged);
        ui.yVarList.Layout.Row    = 3;
        ui.yVarList.Layout.Column = 2;

        % 5) Plot type (simple extension point)
        ui.plotStyleLbl = uilabel(ctrlGrid, ...
            'Text','Plot style:', ...
            'HorizontalAlignment','right');
        ui.plotStyleLbl.Layout.Row    = 5;
        ui.plotStyleLbl.Layout.Column = 1;

        ui.plotStyleDropDown = uidropdown(ctrlGrid, ...
            'Items',{'Line','Line with markers'}, ...
            'ItemsData',{'line','linemarker'});
        ui.plotStyleDropDown.Layout.Row    = 5;
        ui.plotStyleDropDown.Layout.Column = 2;

        % 6) Title edit field
        ui.titleLbl = uilabel(ctrlGrid, ...
            'Text','Title:', ...
            'HorizontalAlignment','right');
        ui.titleLbl.Layout.Row    = 6;
        ui.titleLbl.Layout.Column = 1;

        ui.titleEdit = uieditfield(ctrlGrid,'text', ...
            'Value','', ...
            'ValueChangedFcn',@onLabelEdited);
        ui.titleEdit.Layout.Row    = 6;
        ui.titleEdit.Layout.Column = 2;

        % 7) X label edit field
        ui.xAxisLbl = uilabel(ctrlGrid, ...
            'Text','X label:', ...
            'HorizontalAlignment','right');
        ui.xAxisLbl.Layout.Row    = 7;
        ui.xAxisLbl.Layout.Column = 1;

        ui.xAxisEdit = uieditfield(ctrlGrid,'text', ...
            'Value','', ...
            'ValueChangedFcn',@onLabelEdited);
        ui.xAxisEdit.Layout.Row    = 7;
        ui.xAxisEdit.Layout.Column = 2;

        % 8) Y label edit field
        ui.yAxisLbl = uilabel(ctrlGrid, ...
            'Text','Y label:', ...
            'HorizontalAlignment','right');
        ui.yAxisLbl.Layout.Row    = 8;
        ui.yAxisLbl.Layout.Column = 1;

        ui.yAxisEdit = uieditfield(ctrlGrid,'text', ...
            'Value','', ...
            'ValueChangedFcn',@onLabelEdited);
        ui.yAxisEdit.Layout.Row    = 8;
        ui.yAxisEdit.Layout.Column = 2;

        % 9) Checkboxes for grid and legend
        ui.gridCheck = uicheckbox(ctrlGrid, ...
            'Text','Show grid', ...
            'Value',true);
        ui.gridCheck.Layout.Row    = 9;
        ui.gridCheck.Layout.Column = 1;

        ui.legendCheck = uicheckbox(ctrlGrid, ...
            'Text','Show legend', ...
            'Value',true);
        ui.legendCheck.Layout.Row    = 9;
        ui.legendCheck.Layout.Column = 2;

        % 10) Plot & Export buttons
        ui.plotButton = uibutton(ctrlGrid, ...
            'Text','Plot', ...
            'ButtonPushedFcn',@onPlotPressed);
        ui.plotButton.Layout.Row    = 10;
        ui.plotButton.Layout.Column = 1;

        ui.exportButton = uibutton(ctrlGrid, ...
            'Text','Export PNG...', ...
            'ButtonPushedFcn',@onExportPressed, ...
            'Enable','off');
        ui.exportButton.Layout.Row    = 10;
        ui.exportButton.Layout.Column = 2;

        % Plot area (right)
        ui.axes = uiaxes(bodyGrid);
        ui.axes.Layout.Row    = 1;
        ui.axes.Layout.Column = 2;
        ui.axes.XGrid         = 'on';
        ui.axes.YGrid         = 'on';
        ui.axes.Box           = 'on';
        ui.axes.FontName      = 'Times New Roman';
        ui.axes.FontSize      = 11;
        title(ui.axes,'No data loaded','Interpreter','latex');

        % Status bar (bottom)
        ui.statusLabel = uilabel(mainGrid, ...
            'Text','Ready. Load a CSV log to start.', ...
            'HorizontalAlignment','left');
        ui.statusLabel.Layout.Row    = 3;
        ui.statusLabel.Layout.Column = 1;
    end

    %------------------------- callbacks -------------------------%

    function onLoadLog(~,~)
        % Ask user for a CSV log file
        [fileName,pathName] = uigetfile('*.csv','Select kite log CSV file');
        if isequal(fileName,0)
            return; % user cancelled
        end

        fullName = fullfile(pathName,fileName);

        % Read the log using a dedicated parser
        try
            [dataTable, meta] = readKiteLog(fullName);
        catch ME
            uialert(ui.fig, ...
                sprintf('Error reading log file:\n\n%s',ME.message), ...
                'Read error');
            return;
        end

        % Update UI with variable names
        varNames = string(dataTable.Properties.VariableNames);

        ui.xVarDropDown.Items     = cellstr(varNames);
        ui.xVarDropDown.ItemsData = cellstr(varNames);

        ui.yVarList.Items         = cellstr(varNames);
        ui.yVarList.Value         = cellstr(varNames(contains(varNames,"Var","IgnoreCase",true)));

        % Prefer relative time (seconds) as default X if available
        if isfield(meta,'defaultXVar') && any(varNames == meta.defaultXVar)
            ui.xVarDropDown.Value = meta.defaultXVar;
        else
            ui.xVarDropDown.Value = varNames(1);
        end

        % Sensible default labels
        [defaultTitle,defaultXLabel,defaultYLabel] = defaultLabels(meta,ui.xVarDropDown.Value,ui.yVarList.Value);
        ui.titleEdit.Value = defaultTitle;
        ui.xAxisEdit.Value = defaultXLabel;
        ui.yAxisEdit.Value = defaultYLabel;

        % Update status + file label
        ui.fileLabel.Text   = sprintf('File: %s',fileName);
        ui.statusLabel.Text = sprintf('Loaded %s (%d samples, %d variables).', ...
            fileName, height(dataTable), width(dataTable));

        % Clear axes and disable export until a plot is made
        cla(ui.axes);
        title(ui.axes,'Press "Plot" to visualize data','Interpreter','latex');
        ui.exportButton.Enable = 'off';
    end

    function onXVarChanged(~,~)
        % Whenever the X variable changes, update default X label
        if isempty(dataTable)
            return;
        end
        xVar   = ui.xVarDropDown.Value;
        yVars  = ui.yVarList.Value;
        [~,defaultXLabel,defaultYLabel] = defaultLabels(meta,xVar,yVars);
        if isempty(strtrim(ui.xAxisEdit.Value))
            ui.xAxisEdit.Value = defaultXLabel;
        end
        if isempty(strtrim(ui.yAxisEdit.Value))
            ui.yAxisEdit.Value = defaultYLabel;
        end
    end

    function onYVarChanged(~,~)
        % Update default Y label when Y variables change (if user did not customise)
        if isempty(dataTable)
            return;
        end
        xVar   = ui.xVarDropDown.Value;
        yVars  = ui.yVarList.Value;
        [~,~,defaultYLabel] = defaultLabels(meta,xVar,yVars);
        if isempty(strtrim(ui.yAxisEdit.Value))
            ui.yAxisEdit.Value = defaultYLabel;
        end
    end

    function onLabelEdited(~,~)
        % Just mark that labels were touched – nothing to do right now.
        % This hook makes it easy to extend the app later.
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

        opts.ShowGrid   = logical(ui.gridCheck.Value);
        opts.ShowLegend = logical(ui.legendCheck.Value);
        opts.Style      = ui.plotStyleDropDown.Value;

        % Do the actual plotting
        plotLogData(ui.axes,dataTable,xVar,yVars,labels,opts);

        ui.statusLabel.Text = sprintf('Plotted %d variable(s) vs %s.',numel(yVars),xVar);
        ui.exportButton.Enable = 'on';
    end

    function onExportPressed(~,~)
        if isempty(dataTable)
            uialert(ui.fig,'Nothing to export. Load data and create a plot first.','No data');
            return;
        end

        [fileName,pathName] = uiputfile('*.png','Export plot as PNG');
        if isequal(fileName,0)
            return; % user cancelled
        end

        fullName = fullfile(pathName,fileName);

        try
            exportgraphics(ui.axes,fullName, ...
                'Resolution',300, ...
                'BackgroundColor','white');
        catch ME
            uialert(ui.fig, ...
                sprintf('Error exporting PNG:\n\n%s',ME.message), ...
                'Export error');
            return;
        end

        ui.statusLabel.Text = sprintf('Exported current plot to %s.',fullName);
    end
end

%=========================================================================%
%                         SUBFUNCTIONS BELOW                              %
%=========================================================================%

function [tbl, meta] = readKiteLog(filename)
%READKITELOG  Read kite log CSV with fixed structure.
%
%   [TBL,META] = READKITELOG(FILENAME) reads a CSV file that has:
%       - no header row
%       - timestamp text in column 1
%       - numeric channels in remaining columns
%
%   Returned:
%       TBL   : table with named variables
%       META  : struct with metadata (time variable names etc.)

    % Read raw table (no headers). Use string for text column to simplify.
    tblRaw = readtable(filename, ...
        'FileType','text', ...
        'Delimiter',',', ...
        'ReadVariableNames',false, ...
        'TextType','string');

    nVars = width(tblRaw);

    % Create generic variable names; first is timestamp
    varNames = "Var" + (1:nVars);
    varNames(1) = "TimeStamp";

    tbl = tblRaw;
    tbl.Properties.VariableNames = cellstr(varNames);

    % Convert timestamp column to datetime
    try
        % Typical format: 2025-11-26 13:29:33.169722
        tbl.TimeStamp = datetime(tbl.TimeStamp, ...
            'InputFormat','yyyy-MM-dd HH:mm:ss.SSSSSS', ...
            'TimeZone','');
    catch
        % Fallback to automatic detection if format ever changes
        tbl.TimeStamp = datetime(tbl.TimeStamp);
    end

    % Create relative time in seconds (starting at zero)
    t0           = tbl.TimeStamp(1);
    tbl.Time_s   = seconds(tbl.TimeStamp - t0);

    % Fill metadata
    meta = struct();
    meta.file          = filename;
    meta.timeStampName = "TimeStamp";
    meta.timeSecondsName = "Time_s";
    meta.defaultXVar   = "Time_s";
    meta.variableNames = tbl.Properties.VariableNames;
end

%-------------------------------------------------------------------------%

function plotLogData(ax,tbl,xVar,yVars,labels,opts)
%PLOTLOGDATA  Plot selected variables in the given axes.
%
%   This function is intentionally generic so that it is easy to reuse
%   outside the app if needed.

    % Clear axes and hold on for multiple curves
    cla(ax);
    hold(ax,'on');

    x = tbl.(xVar);

    % Ensure yVars is a cell array of char for indexing
    if isstring(yVars)
        yVars = cellstr(yVars);
    elseif ischar(yVars)
        yVars = {yVars};
    end

    % Use default color order; choose style
    for k = 1:numel(yVars)
        thisY = tbl.(yVars{k});

        switch opts.Style
            case 'linemarker'
                plt = plot(ax,x,thisY,'DisplayName',yVars{k});
                plt.Marker     = '.';
                plt.LineWidth  = 1.2;
            otherwise
                plt = plot(ax,x,thisY,'DisplayName',yVars{k});
                plt.LineWidth  = 1.2;
        end
    end

    hold(ax,'off');

    % Grid and legend
    if opts.ShowGrid
        grid(ax,'on');
    else
        grid(ax,'off');
    end

    if opts.ShowLegend && numel(yVars) > 1
        legend(ax,'show','Interpreter','latex','Location','best');
    else
        legend(ax,'off');
    end

    % LaTeX labels and title
    if ~isempty(strtrim(labels.Title))
        title(ax,labels.Title,'Interpreter','latex');
    else
        title(ax,'','Interpreter','latex');
    end

    if ~isempty(strtrim(labels.XLabel))
        xlabel(ax,labels.XLabel,'Interpreter','latex');
    else
        xlabel(ax,xVar,'Interpreter','latex');
    end

    if ~isempty(strtrim(labels.YLabel))
        ylabel(ax,labels.YLabel,'Interpreter','latex');
    else
        % default: concatenation of variable names
        ylabel(ax,strjoin(yVars,', '),'Interpreter','latex');
    end

    % Nice formatting for time axes (if datetime)
    if isa(x,'datetime')
        ax.XTickLabelRotation = 30;
    else
        ax.XTickLabelRotation = 0;
    end
end

%-------------------------------------------------------------------------%

function [titleStr,xLabelStr,yLabelStr] = defaultLabels(meta,xVar,yVars)
%DEFAULTLABELS  Generate sensible default LaTeX-friendly labels.

    if iscell(xVar); xVar = xVar{1}; end

    % Base file name for title
    if isfield(meta,'file') && ~isempty(meta.file)
        [~,baseName,ext] = fileparts(meta.file);
        filePart = [baseName ext];
    else
        filePart = '';
    end

    if ~isempty(filePart)
        titleStr = sprintf('Log: %s',filePart);
    else
        titleStr = '';
    end

    % X label
    if isfield(meta,'timeSecondsName') && strcmp(xVar,meta.timeSecondsName)
        xLabelStr = 'Time $t$ [s]';
    elseif isfield(meta,'timeStampName') && strcmp(xVar,meta.timeStampName)
        xLabelStr = 'Time stamp';
    else
        xLabelStr = xVar;
    end

    % Y label
    if isstring(yVars); yVars = cellstr(yVars); end
    if ischar(yVars);   yVars = {yVars};       end

    if numel(yVars) == 1
        yLabelStr = yVars{1};
    else
        % Compact concatenation for multiple channels
        yLabelStr = sprintf('Signals: %s',strjoin(yVars,', '));
    end
end
