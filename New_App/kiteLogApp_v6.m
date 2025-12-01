function kiteLogApp_v6
%KITELOGAPP_V6  UC3M AWE kite log plotting app with histograms & boxplots.
%
% Features:
%   - Full control of X/Y labels for all plot types
%   - Multiple CSV logs (multi-kite analysis)
%   - X-range cropping
%   - Legend labels use CSV names by default, or custom labels from "Figure" tab
%   - Extra analysis windows: Wind, Control, Actuators

    % Shared state (captured by nested functions)
    dataTable  = table();    % primary dataset (first loaded log)
    meta       = struct();   % metadata for primary dataset

    dataTables = {};         % cell array of all loaded tables (multi-kite)
    logNames   = {};         % cell array of CSV base names for legends

    ui         = struct();   % UI handles
    Fs         = 40;         % Hz, used in analysis windows
    logTimeWindows = {};

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

        %---------------- Top menu: Analysis (Wind / Control / Actuators) ---%
        ui.menuAnalysis = uimenu(ui.fig, 'Text','Análisis');

        ui.menuWind = uimenu(ui.menuAnalysis, ...
            'Text','Análisis de viento', ...
            'MenuSelectedFcn', @onMenuWindSelected);

        ui.menuControl = uimenu(ui.menuAnalysis, ...
            'Text','Análisis de control', ...
            'MenuSelectedFcn', @onMenuControlSelected);

        ui.menuActuadores = uimenu(ui.menuAnalysis, ...
            'Text','Análisis actuadores', ...
            'MenuSelectedFcn', @onMenuActuadoresSelected);

        %---------------- Top menu: Logs (per-log time windows) ------------%
        ui.menuLogs = uimenu(ui.fig,'Text','Logs');
        ui.menuTimeWindows = uimenu(ui.menuLogs, ...
            'Text','Per-log time windows...', ...
            'MenuSelectedFcn', @onMenuTimeWindowsSelected);


        %---------------- Root layout ----------------%
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
        plotGrid = uigridlayout(ui.tabPlot,[12 2]);
        plotGrid.RowHeight   = {30,30,20,30,20,30,20,'1x',30,20,30,30};
        plotGrid.ColumnWidth = {110,'1x'};

        % 1) Load button (multi-CSV)
        ui.loadButton = uibutton(plotGrid, ...
            'Text','Load CSV log(s)...', ...
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

        % 7) X-range (cropping)
        ui.xRangeLbl = uilabel(plotGrid, ...
            'Text','X range (min max):', ...
            'HorizontalAlignment','right');
        ui.xRangeLbl.Layout.Row    = 10;
        ui.xRangeLbl.Layout.Column = 1;

        ui.xRangeEdit = uieditfield(plotGrid,'text', ...
            'Value','', ...
            'Placeholder','leave empty for full range, e.g. 120 450');
        ui.xRangeEdit.Layout.Row    = 10;
        ui.xRangeEdit.Layout.Column = 2;

        % 8) Grid / legend
        ui.gridCheck = uicheckbox(plotGrid, ...
            'Text','Show grid', ...
            'Value',true);
        ui.gridCheck.Layout.Row    = 11;
        ui.gridCheck.Layout.Column = 1;

        ui.legendCheck = uicheckbox(plotGrid, ...
            'Text','Show legend', ...
            'Value',true);
        ui.legendCheck.Layout.Row    = 11;
        ui.legendCheck.Layout.Column = 2;

        % 9) Plot & export
        ui.plotButton = uibutton(plotGrid, ...
            'Text','Plot', ...
            'ButtonPushedFcn',@onPlotPressed);
        ui.plotButton.Layout.Row    = 12;
        ui.plotButton.Layout.Column = 1;

        ui.exportButton = uibutton(plotGrid, ...
            'Text','Export PNG...', ...
            'ButtonPushedFcn',@onExportPressed, ...
            'Enable','off');
        ui.exportButton.Layout.Row    = 12;
        ui.exportButton.Layout.Column = 2;

        %---------------- FIGURE TAB ----------------%
        figGrid = uigridlayout(ui.tabFigure,[13 2]);
        figGrid.RowHeight   = {20,30,20,30,20,30,30,30,30,30,30,30,30};
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
            'Text','Y label (all plots):', ...
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

        % Variable legend names (one mapping per line: raw = pretty)
        ui.varLegendLbl = uilabel(figGrid, ...
            'Text','', ...
            'HorizontalAlignment','right');
        ui.varLegendLbl.Layout.Row    = 11;
        ui.varLegendLbl.Layout.Column = 1;
        
        ui.varLegendEdit = uitextarea(figGrid, ...
            'Value', {''}, ...
            'Placeholder','e.g. ADC_LC_center = Línea central', ...
            'ValueChangedFcn',@onLabelEdited);
        ui.varLegendEdit.Layout.Row    = 11;
        ui.varLegendEdit.Layout.Column = 2;

        % NEW: custom legend labels
        ui.legendLabelsLbl = uilabel(figGrid, ...
            'Text','Legend labels (comma-separated):', ...
            'HorizontalAlignment','right');
        ui.legendLabelsLbl.Layout.Row    = 11;
        ui.legendLabelsLbl.Layout.Column = 1;

        ui.legendLabelsEdit = uieditfield(figGrid,'text', ...
            'Value','', ...
            'Placeholder','e.g. Kite A, Kite B, Kite C');
        ui.legendLabelsEdit.Layout.Row    = 11;
        ui.legendLabelsEdit.Layout.Column = 2;

        ui.colorLbl = uilabel(figGrid, ...
            'Text','Color scheme:', ...
            'HorizontalAlignment','right');
        ui.colorLbl.Layout.Row    = 12;
        ui.colorLbl.Layout.Column = 1;

        ui.colorDropDown = uidropdown(figGrid, ...
            'Items',{'Default','Lines','Parula','Turbo','Gray'}, ...
            'Value','Default');
        ui.colorDropDown.Layout.Row    = 12;
        ui.colorDropDown.Layout.Column = 2;

        ui.plotStyleLbl = uilabel(figGrid, ...
            'Text','Plot style (time series):', ...
            'HorizontalAlignment','right');
        ui.plotStyleLbl.Layout.Row    = 13;
        ui.plotStyleLbl.Layout.Column = 1;

        ui.plotStyleDropDown = uidropdown(figGrid, ...
            'Items',{'Line','Line with markers','Scatter'}, ...
            'Value','Line');
        ui.plotStyleDropDown.Layout.Row    = 13;
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
            'Text','Ready. Load one or more CSV logs to start.', ...
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
        figSettings.ColorScheme    = lower(strrep(rawColor,' ','')); % 'default','parula',...
        figSettings.PlotStyle      = mapPlotStyle(ui.plotStyleDropDown.Value);
        figSettings.FontName       = 'Times New Roman';
    end

    % Refresh Y-variable list depending on plot type
    function updateYVarListForPlotKind(kind)
        if nargin < 1 || isempty(kind)
            kind = ui.plotKindDropDown.Value;
        end

        if isempty(dataTable)
            ui.yVarList.Items = {};
            ui.yVarList.Value = {};
            return;
        end

        switch kind
            case 'boxplot'
                if isfield(meta,'boxplotVars') && ~isempty(meta.boxplotVars)
                    list = string(meta.boxplotVars);
                else
                    list = string([]);
                end
            case 'histogram'
                if isfield(meta,'tensionVars') && ~isempty(meta.tensionVars)
                    list = string(meta.tensionVars);
                else
                    list = string([]);
                end
            otherwise % 'timeseries'
                if isfield(meta,'allYVars') && ~isempty(meta.allYVars)
                    list = string(meta.allYVars);
                else
                    list = string([]);
                end
        end

        ui.yVarList.Items = cellstr(list);

        if isempty(list)
            ui.yVarList.Value = {};
        else
            oldVal  = string(ui.yVarList.Value);
            keep    = ismember(oldVal,list);
            newVal  = oldVal(keep);
            if isempty(newVal)
                nDefault = min(3,numel(list));
                newVal   = list(1:nDefault);
            end
            ui.yVarList.Value = cellstr(newVal);
        end
    end

    function onPlotKindChanged(src,~)
        kind   = src.Value;                 % 'timeseries' | 'histogram' | 'boxplot'
        isTime = strcmp(kind,'timeseries');

        if isTime
            ui.xLabelLbl.Enable      = 'on';
            ui.xVarDropDown.Enable   = 'on';
            ui.layoutLbl.Enable      = 'on';
            ui.layoutDropDown.Enable = 'on';
        else
            ui.xLabelLbl.Enable      = 'off';
            ui.xVarDropDown.Enable   = 'off';
            ui.layoutLbl.Enable      = 'off';
            ui.layoutDropDown.Enable = 'off';

            if strcmp(kind,'histogram')
                ui.layoutDropDown.Value = 'stacked';
            else
                ui.layoutDropDown.Value = 'single';
            end
        end

        if strcmp(kind,'histogram')
            ui.yVarList.Enable = 'off';
            ui.yLabelLbl.Text  = 'Y variable(s): (tether tension)';
        else
            ui.yVarList.Enable = 'on';
            ui.yLabelLbl.Text  = 'Y variable(s):';
        end

        updateYVarListForPlotKind(kind);
    end

    function onLoadLog(~,~)
        [fileName,pathName] = uigetfile('*.csv', ...
            'Select kite log CSV file(s)','MultiSelect','on');
        if isequal(fileName,0)
            return;
        end

        % Normalize to cell array of filenames
        if ischar(fileName)
            fileNames = {fileName};
        else
            fileNames = fileName;
        end

        nFiles        = numel(fileNames);
        dataTables    = cell(1,nFiles);
        logNames      = cell(1,nFiles);   %#ok<NASGU>
        logTimeWindows = cell(1,nFiles);  % NEW: clear per-log windows


        for k = 1:nFiles
            fullName = fullfile(pathName,fileNames{k});
            try
                [tbl, mt] = readKiteLog(fullName);
            catch ME
                uialert(ui.fig, ...
                    sprintf('Error reading log file "%s":\n\n%s', ...
                    fileNames{k}, ME.message), ...
                    'Read error');
                return;
            end

            dataTables{k} = tbl;

            [~,baseName,ext] = fileparts(fileNames{k});
            logNames{k} = [baseName ext];

            if k == 1
                dataTable = tbl;
                meta      = mt;
            end
        end

        varNames = string(dataTable.Properties.VariableNames);

        ui.xVarDropDown.Items     = cellstr(varNames);
        ui.xVarDropDown.ItemsData = cellstr(varNames);

        numericMask = varfun(@isnumeric,dataTable,'OutputFormat','uniform');
        yNames      = varNames(numericMask);

        meta.allYVars = yNames;

        tensionCandidates = ["ADC_LC_left","ADC_LC_center","ADC_LC_right", ...
                             "LC_left","LC_center","LC_right"];
        meta.tensionVars = tensionCandidates(ismember(tensionCandidates,yNames));

        boxplotCandidates = ["CONTROL_deltaL","CONTROL_thirdLineDeltaL"];
        meta.boxplotVars  = boxplotCandidates(ismember(boxplotCandidates,yNames));

        updateYVarListForPlotKind();

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

        if nFiles == 1
            ui.fileLabel.Text = sprintf('File: %s',fileNames{1});
            ui.statusLabel.Text = sprintf('Loaded %s (%d samples, %d variables).', ...
                fileNames{1},height(dataTable),width(dataTable));
        else
            ui.fileLabel.Text = sprintf('Files: %s (+%d more)', ...
                fileNames{1}, nFiles-1);
            ui.statusLabel.Text = sprintf('Loaded %d log file(s). First: %s (%d samples, %d variables).', ...
                nFiles, fileNames{1}, height(dataTable), width(dataTable));
        end

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

        if isfield(ui,'windFig') && ~isempty(ui.windFig) && isvalid(ui.windFig)
            plotWindAnalysis();
        end
        if isfield(ui,'controlFig') && ~isempty(ui.controlFig) && isvalid(ui.controlFig)
            plotControlAnalysis();
        end
        if isfield(ui,'actFig') && ~isempty(ui.actFig) && isvalid(ui.actFig)
            plotActuatorsAnalysis();
        end
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
        % user edit fields already store overrides
    end

    function onPlotPressed(~,~)
        if isempty(dataTables)
            if isempty(dataTable)
                uialert(ui.fig,'Please load one or more CSV logs first.','No data');
                return;
            else
                dataTables = {dataTable};
                if isempty(logNames)
                    logNames = {'Log 1'};
                end
            end
        end

        xVar  = ui.xVarDropDown.Value;
        yVars = ui.yVarList.Value;
        kind  = ui.plotKindDropDown.Value;

        if isempty(yVars) && ~strcmp(kind,'histogram')
            uialert(ui.fig,'Select at least one Y variable to plot.','No Y variable');
            return;
        end

        labels.Title  = ui.titleEdit.Value;
        labels.XLabel = ui.xAxisEdit.Value;
        labels.YLabel = ui.yAxisEdit.Value;

        plotOpts.ShowGrid   = logical(ui.gridCheck.Value);
        plotOpts.ShowLegend = logical(ui.legendCheck.Value);
        plotOpts.Layout     = ui.layoutDropDown.Value;
        plotOpts.PlotKind   = kind;

        % Global X-range (applied to all logs unless overridden)
        rawRange = strtrim(ui.xRangeEdit.Value);
        plotOpts.XRangeGlobal = [];
        if ~isempty(rawRange)
            nums = sscanf(rawRange,'%f');
            if numel(nums) >= 2
                xr = double(nums(1:2).');
                if xr(2) < xr(1)
                    xr = fliplr(xr);
                end
                plotOpts.XRangeGlobal = xr;
            end
        end

        % NEW: per-log windows from the Logs menu
        plotOpts.XRangePerLog = logTimeWindows;

        plotOpts.LogNames   = logNames;
        plotOpts.LegendText = ui.legendLabelsEdit.Value;
        plotOpts.VarLegendText = ui.varLegendEdit.Value;   % <-- variable legend names


        figSettings = getFigureSettings();

        plotLogData(ui.plotGrid,dataTables,xVar,yVars,labels,plotOpts,figSettings);

        ui.statusLabel.Text = sprintf('%s plot of %d variable(s) for %d log(s).', ...
            upper(kind(1)), max(1,numel(yVars)), numel(dataTables));
        ui.exportButton.Enable = 'on';
    end

    function onExportPressed(~,~)
        if isempty(dataTables) && isempty(dataTable)
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

    %------------------ Analysis menu callbacks ------------------------%
    function onMenuWindSelected(~,~)
        openWindAnalysisWindow();
        plotWindAnalysis();
    end

    function onMenuControlSelected(~,~)
        openControlAnalysisWindow();
        plotControlAnalysis();
    end

    function onMenuActuadoresSelected(~,~)
        openActuatorsAnalysisWindow();
        plotActuatorsAnalysis();
    end

    %================= Wind analysis window ============================%
    function openWindAnalysisWindow()
        if isfield(ui,'windFig') && ~isempty(ui.windFig) && isvalid(ui.windFig)
            figure(ui.windFig);
            return;
        end

        ui.windFig = uifigure('Name','Análisis de Viento', ...
                              'Position',[150 100 1100 650]);

        ui.windTimeAx = uiaxes(ui.windFig, 'Position', [50 360 1000 250]);
        title(ui.windTimeAx, 'Wind Speed vs Tiempo');
        xlabel(ui.windTimeAx, 'Tiempo (s)');
        ylabel(ui.windTimeAx, 'WIND\_speed');
        grid(ui.windTimeAx,'on');

        ui.windHistAx = uiaxes(ui.windFig, 'Position', [50 50 480 260]);
        title(ui.windHistAx, 'Distribución de WIND\_speed');
        xlabel(ui.windHistAx, 'WIND\_speed'); 
        ylabel(ui.windHistAx, 'Cuenta');
        grid(ui.windHistAx,'on');

        ui.windPolarAx = polaraxes('Parent', ui.windFig);
        set(ui.windPolarAx, 'Units','normalized', 'Position',[0.62 0.08 0.34 0.40]);
        title(ui.windPolarAx, 'Rosa (dirección/velocidad)');
        thetalim(ui.windPolarAx, [0 360]);
        rtickformat(ui.windPolarAx, '%.0f');
        ui.windPolarAx.ThetaZeroLocation = 'top';
        ui.windPolarAx.ThetaDir          = 'clockwise';
        thetaticks(ui.windPolarAx, 0:45:315);
        thetaticklabels(ui.windPolarAx, {'N','NE','E','SE','S','SW','W','NW'});
    end

    function plotWindAnalysis()
        if ~isfield(ui,'windFig') || isempty(ui.windFig) || ~isvalid(ui.windFig)
            return;
        end

        if isempty(dataTable) || height(dataTable)==0
            uialert(ui.windFig, 'No hay datos cargados. Carga un log CSV primero.', 'Sin datos');
            return;
        end

        names = dataTable.Properties.VariableNames;
        if ~ismember('WIND_speed',names) || ~ismember('WIND_direction',names)
            uialert(ui.windFig, 'Faltan columnas WIND\_speed o WIND\_direction en los datos.', 'Datos insuficientes');
            return;
        end

        ws = dataTable.WIND_speed(:);
        wd = dataTable.WIND_direction(:);
        good = isfinite(ws) & isfinite(wd);
        ws = ws(good); 
        wd = wd(good);

        if isempty(ws)
            cla(ui.windTimeAx); 
            cla(ui.windHistAx); 
            cla(ui.windPolarAx);
            title(ui.windTimeAx,'Sin datos válidos'); 
            title(ui.windHistAx,''); 
            title(ui.windPolarAx,'');
            return;
        end

        t = (0:numel(ws)-1)'/Fs;
        cla(ui.windTimeAx);
        plot(ui.windTimeAx, t, ws, '-', 'LineWidth', 1);
        grid(ui.windTimeAx,'on');
        xlabel(ui.windTimeAx, sprintf('Tiempo (s) — Fs=%.3g Hz', Fs));
        ylabel(ui.windTimeAx, 'WIND\_speed');

        cla(ui.windHistAx);
        histogram(ui.windHistAx, ws, 'BinMethod','fd');
        grid(ui.windHistAx,'on');
        xlabel(ui.windHistAx, 'WIND\_speed'); 
        ylabel(ui.windHistAx, 'Cuenta');

        cla(ui.windPolarAx); 
        hold(ui.windPolarAx,'on');
        theta = deg2rad(wd);
        mask1 = ws <= 5;
        mask2 = ws > 5  & ws <= 10;
        mask3 = ws > 10 & ws <= 15;
        mask4 = ws > 15;

        if any(mask1)
            polarscatter(ui.windPolarAx, theta(mask1), ws(mask1), 12, 'filled', ...
                'MarkerFaceColor',[0 0 1], 'MarkerEdgeColor','k', 'DisplayName','<=5');
        end
        if any(mask2)
            polarscatter(ui.windPolarAx, theta(mask2), ws(mask2), 12, 'filled', ...
                'MarkerFaceColor',[1 1 0], 'MarkerEdgeColor','k', 'DisplayName','5-10');
        end
        if any(mask3)
            polarscatter(ui.windPolarAx, theta(mask3), ws(mask3), 12, 'filled', ...
                'MarkerFaceColor',[0 0.6 0], 'MarkerEdgeColor','k', 'DisplayName','10-15');
        end
        if any(mask4)
            polarscatter(ui.windPolarAx, theta(mask4), ws(mask4), 12, 'filled', ...
                'MarkerFaceColor',[1 0 0], 'MarkerEdgeColor','k', 'DisplayName','>15');
        end

        thetalim(ui.windPolarAx, [0 360]); 
        rtick(ui.windPolarAx, 'auto');
        grid(ui.windPolarAx,'on');
        legend(ui.windPolarAx, 'Location','northeastoutside', 'Title','Wind Speed (m/s)');
        hold(ui.windPolarAx,'off');
    end

    %================= Control analysis window ==========================%
    function openControlAnalysisWindow()
        if isfield(ui,'controlFig') && ~isempty(ui.controlFig) && isvalid(ui.controlFig)
            figure(ui.controlFig);
            return;
        end

        ui.controlFig = uifigure('Name','Análisis de control', ...
                                 'Position',[200 120 1000 700]);

        ui.controlScatterAx = uiaxes(ui.controlFig, 'Position', [60 400 880 250]);
        title(ui.controlScatterAx, '\phi vs \beta (scatter)');
        xlabel(ui.controlScatterAx, '\phi'); 
        ylabel(ui.controlScatterAx, '\beta'); 
        grid(ui.controlScatterAx,'on');

        ui.controlPsiAx = uiaxes(ui.controlFig, 'Position', [60 80 880 250]);
        title(ui.controlPsiAx, '\psi y \psi_{set} vs tiempo');
        xlabel(ui.controlPsiAx, 'Tiempo (s)'); 
        ylabel(ui.controlPsiAx, '\psi'); 
        grid(ui.controlPsiAx,'on');
        legend(ui.controlPsiAx,'off');
    end

    function plotControlAnalysis()
        if ~isfield(ui,'controlFig') || isempty(ui.controlFig) || ~isvalid(ui.controlFig)
            return;
        end

        if isempty(dataTable) || height(dataTable)==0
            uialert(ui.controlFig, 'No hay datos cargados. Carga un log CSV primero.', 'Sin datos');
            return;
        end

        names = dataTable.Properties.VariableNames;
        havePhi  = ismember('CONTROL_phi', names);
        haveBeta = ismember('CONTROL_beta', names);
        havePsi  = ismember('CONTROL_psi', names);
        havePsiS = ismember('CONTROL_psi_set', names);

        cla(ui.controlScatterAx);
        if havePhi && haveBeta
            phi  = dataTable.CONTROL_phi(:);
            beta = dataTable.CONTROL_beta(:);
            good = isfinite(phi) & isfinite(beta);
            phi  = phi(good); 
            beta = beta(good);
            if ~isempty(phi)
                scatter(ui.controlScatterAx, phi, beta, 10, 'filled');
            else
                text(ui.controlScatterAx,0.5,0.5,'Sin datos válidos', ...
                    'HorizontalAlignment','center','Units','normalized');
            end
        else
            text(ui.controlScatterAx,0.5,0.5,'Faltan CONTROL\_phi o CONTROL\_beta', ...
                'HorizontalAlignment','center','Units','normalized');
        end
        grid(ui.controlScatterAx,'on');

        cla(ui.controlPsiAx);
        if havePsi && havePsiS
            psi    = dataTable.CONTROL_psi(:);
            psiSet = dataTable.CONTROL_psi_set(:);

            n = min(numel(psi), numel(psiSet));
            psi    = psi(1:n); 
            psiSet = psiSet(1:n);

            t = (0:n-1)'/Fs;
            good = isfinite(t) & isfinite(psi) & isfinite(psiSet);
            t = t(good); 
            psi = psi(good); 
            psiSet = psiSet(good);

            if ~isempty(t)
                hold(ui.controlPsiAx,'on');
                plot(ui.controlPsiAx, t, psi, '-', 'LineWidth', 1.1, 'DisplayName','\psi');
                plot(ui.controlPsiAx, t, psiSet, '-', 'LineWidth', 1.1, 'DisplayName','\psi_{set}');
                hold(ui.controlPsiAx,'off');
                legend(ui.controlPsiAx,'Location','best');
            else
                text(ui.controlPsiAx,0.5,0.5,'Sin datos válidos', ...
                    'HorizontalAlignment','center','Units','normalized');
                legend(ui.controlPsiAx,'off');
            end
        else
            text(ui.controlPsiAx,0.5,0.5,'Faltan CONTROL\_psi o CONTROL\_psi\_set', ...
                'HorizontalAlignment','center','Units','normalized');
            legend(ui.controlPsiAx,'off');
        end
        xlabel(ui.controlPsiAx, sprintf('Tiempo (s) — Fs=%.3g Hz', Fs));
        ylabel(ui.controlPsiAx, '\psi');
        grid(ui.controlPsiAx,'on');
    end

    %================= Actuators analysis window ========================%
    function openActuatorsAnalysisWindow()
        if isfield(ui,'actFig') && ~isempty(ui.actFig) && isvalid(ui.actFig)
            figure(ui.actFig);
            return;
        end

        ui.actFig = uifigure('Name','Análisis actuadores', ...
                             'Position',[220 100 1200 720]);

        ui.actShowTotalCB = uicheckbox(ui.actFig, ...
            'Text','Mostrar potencia total (P10+P20+P21+P30)', ...
            'Value', false, ...
            'Position', [40 685 400 22], ...
            'ValueChangedFcn', @onActShowTotalChanged);

        ui.actAxes = uiaxes(ui.actFig, 'Position', [40 380 820 290]);
        title(ui.actAxes, 'Potencia actuadores (W)');
        xlabel(ui.actAxes, 'Tiempo (s)'); 
        ylabel(ui.actAxes, 'Potencia (W)');
        grid(ui.actAxes, 'on');

        ui.actEnergyAx = uiaxes(ui.actFig, 'Position', [40 80 820 260]);
        title(ui.actEnergyAx, 'Energía consumida por los actuadores (Wh)');
        xlabel(ui.actEnergyAx, 'Tiempo (s)'); 
        ylabel(ui.actEnergyAx, 'Energía (Wh)');
        grid(ui.actEnergyAx, 'on');

        ui.actStatsTable = uitable(ui.actFig, ...
            'Position', [880 80 300 590], ...
            'ColumnName', {'Variable','Mín','Máx','Media'}, ...
            'ColumnEditable', [false false false false], ...
            'ColumnWidth', {80, 70, 70, 80}, ...
            'Data', cell(0,4));
        ui.actStatsTable.ColumnFormat = {'char','char','char','char'};
    end

    function onActShowTotalChanged(~,~)
        plotActuatorsAnalysis();
    end

    function plotActuatorsAnalysis()
        if ~isfield(ui,'actFig') || isempty(ui.actFig) || ~isvalid(ui.actFig)
            return;
        end

        cla(ui.actAxes); 
        cla(ui.actEnergyAx);
        ui.actStatsTable.Data = cell(0,4);

        if isempty(dataTable) || height(dataTable)==0
            text(ui.actAxes,0.5,0.5,'No hay datos cargados','HorizontalAlignment','center','Units','normalized');
            text(ui.actEnergyAx,0.5,0.5,'Sin datos','HorizontalAlignment','center','Units','normalized');
            return;
        end

        names = dataTable.Properties.VariableNames;
        need = {'DPRO_10_current','DPRO_20_current','DPRO_21_current','DPRO_30_current','DPRO_voltage_48'};
        hasAll = all(ismember(need, names));

        if ~hasAll
            text(ui.actAxes,0.5,0.5,'Faltan DPRO\_xx\_current o DPRO\_voltage\_48','HorizontalAlignment','center','Units','normalized');
            text(ui.actEnergyAx,0.5,0.5,'Sin datos','HorizontalAlignment','center','Units','normalized');
            return;
        end

        i10 = dataTable.DPRO_10_current(:);
        i20 = dataTable.DPRO_20_current(:);
        i21 = dataTable.DPRO_21_current(:);
        i30 = dataTable.DPRO_30_current(:);
        v48 = dataTable.DPRO_voltage_48(:);

        n = min([numel(i10), numel(i20), numel(i21), numel(i30), numel(v48)]);
        i10 = i10(1:n); 
        i20 = i20(1:n); 
        i21 = i21(1:n); 
        i30 = i30(1:n); 
        v48 = v48(1:n);

        P10 = (i10 .* v48) / 1000000;
        P20 = (i20 .* v48) / 1000000;
        P21 = -(i21 .* v48) / 1000000;
        P30 = (i30 .* v48) / 1000000;

        t = (0:n-1)'/Fs;
        good = isfinite(t) & isfinite(P10) & isfinite(P20) & isfinite(P21) & isfinite(P30);
        t   = t(good); 
        P10 = P10(good); 
        P20 = P20(good); 
        P21 = P21(good); 
        P30 = P30(good);

        if isempty(t)
            text(ui.actAxes,0.5,0.5,'Sin datos válidos','HorizontalAlignment','center','Units','normalized');
            text(ui.actEnergyAx,0.5,0.5,'Sin datos válidos','HorizontalAlignment','center','Units','normalized');
            return;
        end

        hold(ui.actAxes,'on');
        plot(ui.actAxes, t, P10, '-', 'LineWidth', 1.1, 'DisplayName','P10 (W)');
        plot(ui.actAxes, t, P20, '-', 'LineWidth', 1.1, 'DisplayName','P20 (W)');
        plot(ui.actAxes, t, P21, '-', 'LineWidth', 1.1, 'DisplayName','P21 (W)');
        plot(ui.actAxes, t, P30, '-', 'LineWidth', 1.1, 'DisplayName','P30 (W)');

        Psum = P10 + P20 + P21 + P30;
        if isfield(ui,'actShowTotalCB') && ~isempty(ui.actShowTotalCB) && isvalid(ui.actShowTotalCB) ...
                && logical(ui.actShowTotalCB.Value)
            plot(ui.actAxes, t, Psum, '-', 'LineWidth', 1.8, 'Color',[0 0 0], 'DisplayName','P_{tot} (W)');
        end
        hold(ui.actAxes,'off');
        legend(ui.actAxes,'Location','best');
        xlabel(ui.actAxes, sprintf('Tiempo (s) — Fs=%.3g Hz', Fs));
        ylabel(ui.actAxes, 'Potencia (W)');
        grid(ui.actAxes,'on');
        try, ytickformat(ui.actAxes,'%.0f'); end
        try, ui.actAxes.YRuler.Exponent = 0; end

        dt = 1/Fs;
        Ewh = cumsum(Psum) * dt / 3600;

        Ewh_pos = Ewh; Ewh_pos(Psum < 0)  = NaN;
        Ewh_neg = Ewh; Ewh_neg(Psum >= 0) = NaN;

        hold(ui.actEnergyAx,'on');
        plot(ui.actEnergyAx, t, Ewh_pos, '.', 'LineWidth', 0.5, 'Color',[1 0 0],   'DisplayName','E (+P) [Wh]');
        plot(ui.actEnergyAx, t, Ewh_neg, '.', 'LineWidth', 0.5, 'Color',[0 0.6 0], 'DisplayName','E (-P) [Wh]');
        hold(ui.actEnergyAx,'off');
        legend(ui.actEnergyAx,'Location','best');
        title(ui.actEnergyAx, 'Energía consumida por los actuadores (Wh)');
        xlabel(ui.actEnergyAx, sprintf('Tiempo (s) — Fs=%.3g Hz', Fs));
        ylabel(ui.actEnergyAx, 'Energía (Wh)');
        grid(ui.actEnergyAx,'on');
        try, ytickformat(ui.actEnergyAx,'%.0f'); end
        try, ui.actEnergyAx.YRuler.Exponent = 0; end

        stats = @(x) [min(x), max(x), mean(x)];
        s10 = stats(P10); 
        s20 = stats(P20); 
        s21 = stats(P21); 
        s30 = stats(P30);

        fmt = @(x) sprintf('%.0f', x);
        ui.actStatsTable.Data = {
            'P10', fmt(s10(1)), fmt(s10(2)), fmt(s10(3));
            'P20', fmt(s20(1)), fmt(s20(2)), fmt(s20(3));
            'P21', fmt(s21(1)), fmt(s21(2)), fmt(s21(3));
            'P30', fmt(s30(1)), fmt(s30(2)), fmt(s30(3));
        };
    end

    %------------------ Logs menu: per-log time windows ------------------%
    function onMenuTimeWindowsSelected(~,~)
        if isempty(dataTables)
            uialert(ui.fig,'Load one or more CSV logs first.','No logs');
            return;
        end

        % If already open, just bring to front & refresh
        if isfield(ui,'timeWinFig') && ~isempty(ui.timeWinFig) && isvalid(ui.timeWinFig)
            figure(ui.timeWinFig);
            populateTimeWindowTable();
            return;
        end

        ui.timeWinFig = uifigure('Name','Per-log time windows', ...
                                 'Position',[250 200 520 320]);

        ui.timeWinTable = uitable(ui.timeWinFig, ...
            'Position',[20 60 480 230], ...
            'ColumnName',{'Log','t_{min} [s]','t_{max} [s]'}, ...
            'ColumnEditable',[false true true], ...
            'CellEditCallback', @onTimeWindowCellEdit);

        uilabel(ui.timeWinFig, ...
            'Text','Leave t_{min} or t_{max} empty for "no limit". Times are in the current X variable (e.g. Time\_s).', ...
            'Position',[20 25 480 20]);

        populateTimeWindowTable();
    end

    function populateTimeWindowTable()
        if isempty(dataTables)
            return;
        end

        nLogs = numel(dataTables);
        data  = cell(nLogs,3);

        for j = 1:nLogs
            % Log name column
            if j <= numel(logNames) && ~isempty(logNames{j})
                data{j,1} = logNames{j};
            else
                data{j,1} = sprintf('Log %d',j);
            end

            % Time window columns as strings
            if j <= numel(logTimeWindows) && ~isempty(logTimeWindows{j})
                w = logTimeWindows{j};
                data{j,2} = num2str(w(1),'%.3f');
                data{j,3} = num2str(w(2),'%.3f');
            else
                data{j,2} = '';
                data{j,3} = '';
            end
        end

        ui.timeWinTable.Data = data;
    end

    function onTimeWindowCellEdit(~,~)
        % Re-parse entire table into logTimeWindows
        data  = ui.timeWinTable.Data;
        nLogs = size(data,1);
        logTimeWindows = cell(1,nLogs);  % overwrite outer variable

        for j = 1:nLogs
            tminStr = strtrim(data{j,2});
            tmaxStr = strtrim(data{j,3});

            if isempty(tminStr) && isempty(tmaxStr)
                logTimeWindows{j} = [];
                continue;
            end

            tmin = str2double(tminStr);
            tmax = str2double(tmaxStr);

            if isnan(tmin), tmin = -inf; end
            if isnan(tmax), tmax =  inf; end

            if isfinite(tmin) && isfinite(tmax) && tmax < tmin
                tmp  = tmin; 
                tmin = tmax; 
                tmax = tmp;
            end

            logTimeWindows{j} = [tmin tmax];
        end
    end


end

%=========================================================================%
%                         LOCAL FUNCTIONS                                 %
%=========================================================================%

function [tbl, meta] = readKiteLog(filename)
%READKITELOG  Read kite log CSV and assign fixed channel names.

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

    raw = readmatrix(filename, ...
        'FileType','text', ...
        'Delimiter',',', ...
        'Range','B1');   % skip column 1 (text / index)
    nCols = size(raw, 2);

    if nCols > numel(varNames)
        for i = numel(varNames)+1:nCols
            varNames{end+1} = sprintf('extra_col_%d', i);
        end
    elseif nCols < numel(varNames)
        varNames = varNames(1:nCols);
    end

    tbl = array2table(raw, 'VariableNames', varNames);

    if ismember('CONTROL_timestamp_us', varNames)
        t0         = tbl.CONTROL_timestamp_us(1);
        tbl.Time_s = (tbl.CONTROL_timestamp_us - t0) * 1e-6;  % µs -> s
    else
        tbl.Time_s = (0:height(tbl)-1).';
    end

    if height(tbl) > 0
        tbl.Properties.VariableNames = circshift(tbl.Properties.VariableNames, -1);
    end

    meta = struct();
    meta.file            = filename;
    meta.timeStampName   = 'CONTROL_timestamp_us';
    meta.timeSecondsName = 'Time_s';
    meta.defaultXVar     = 'CONTROL_timestamp_us';
    meta.variableNames   = tbl.Properties.VariableNames;
end

%-------------------------------------------------------------------------%

function plotLogData(plotGrid,tbl,xVar,yVars,labels,plotOpts,figSettings)
    if istable(tbl)
        tblCell = {tbl};
    elseif iscell(tbl)
        tblCell = tbl;
    else
        error('tbl must be a table or a cell array of tables.');
    end

    switch plotOpts.PlotKind
        case 'histogram'
            plotHistogramGrid(plotGrid,tblCell,xVar,yVars,labels,plotOpts,figSettings);
        case 'boxplot'
            plotBoxplotGrid(plotGrid,tblCell,xVar,yVars,labels,plotOpts,figSettings);
        otherwise
            plotTimeSeriesGrid(plotGrid,tblCell,xVar,yVars,labels,plotOpts,figSettings);
    end
end

%-------------------------------------------------------------------------%

function plotTimeSeriesGrid(plotGrid,tblCell,xVar,yVars,labels,plotOpts,figSettings)

    if ~iscell(tblCell)
        tblCell = {tblCell};
    end

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
        plotSingleAxes(ax,tblCell,xVar,yVars,labels,plotOpts,figSettings);
    else
        plotGrid.RowHeight   = repmat({'1x'},1,nY);
        plotGrid.ColumnWidth = {'1x'};
        for k = 1:nY
            ax = uiaxes(plotGrid);
            ax.Layout.Row    = k;
            ax.Layout.Column = 1;

            localLabels = labels;
            if k ~= 1
                % Only the top subplot shows the main title
                localLabels.Title = '';
            end
            % IMPORTANT: do NOT clear XLabel here -> same X label on all
            plotSingleAxes(ax,tblCell,xVar,yVars(k),localLabels,plotOpts,figSettings);
        end
    end
end

%-------------------------------------------------------------------------%

function plotHistogramGrid(plotGrid,tblCell,xVar,~,labels,plotOpts,figSettings)
% tension-distribution histogram (central/left/right) for multiple logs

    if ~iscell(tblCell)
        tblCell = {tblCell};
    end
    nLogs = numel(tblCell);

    legendNamesAll = buildLegendNames(plotOpts,nLogs);

    lineData = cell(nLogs,3);
    validLog = false(1,nLogs);

    for j = 1:nLogs
        tbl = tblCell{j};
        if ~istable(tbl) || height(tbl)==0
            continue;
        end

        % Per-log effective range
        xRange = getEffectiveXRange(plotOpts,j);
        if ~isempty(xRange) && numel(xRange)==2 && ismember(xVar,tbl.Properties.VariableNames)
            x = tbl.(xVar);
            if isnumeric(x)
                mask = isfinite(x) & x >= xRange(1) & x <= xRange(2);
                tbl = tbl(mask,:);
            end
        end
        if height(tbl)==0
            continue;
        end

        names = tbl.Properties.VariableNames;

        candidateSets = {
            {'ADC_LC_left','ADC_LC_center','ADC_LC_right'}
            {'LC_left','LC_center','LC_right'}
        };

        lineVars = {};
        for s = 1:numel(candidateSets)
            if all(ismember(candidateSets{s}, names))
                lineVars = candidateSets{s};
                break;
            end
        end

        if isempty(lineVars)
            continue;
        end

        L  = tbl.(lineVars{1});
        C  = tbl.(lineVars{2});
        R  = tbl.(lineVars{3});

        sumT = L + C + R;
        valid = isfinite(sumT) & sumT > 0 & ...
                isfinite(L) & isfinite(C) & isfinite(R);

        Ln = L(valid) ./ sumT(valid);
        Cn = C(valid) ./ sumT(valid);
        Rn = R(valid) ./ sumT(valid);

        Ln = Ln(Ln >= 0 & Ln <= 1);
        Cn = Cn(Cn >= 0 & Cn <= 1);
        Rn = Rn(Rn >= 0 & Rn <= 1);

        lineData{j,1} = Cn;
        lineData{j,2} = Ln;
        lineData{j,3} = Rn;
        validLog(j)   = ~isempty(Cn) || ~isempty(Ln) || ~isempty(Rn);
    end

    if ~any(validLog)
        plotHistogramGridGeneric(plotGrid,tblCell,xVar,{},labels,plotOpts,figSettings);
        return;
    end

    delete(plotGrid.Children);
    plotGrid.RowHeight   = repmat({'1x'},1,3);
    plotGrid.ColumnWidth = {'1x'};

    lineTitles  = {'Línea central','Línea izquierda','Línea derecha'};
    logIndices  = find(validLog);
    nUseLogs    = numel(logIndices);
    colors      = chooseColorScheme(figSettings.ColorScheme,max(nUseLogs,1));

    for k = 1:3
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

        hold(ax,'on');
        for idx = 1:nUseLogs
            j = logIndices(idx);
            dataK = lineData{j,k};
            if isempty(dataK)
                continue;
            end
            dispName = legendNamesAll{j};

            h = histogram(ax,dataK, ...
                'NumBins',50, ...
                'BinLimits',[0 1], ...
                'DisplayName', dispName);
            h.FaceColor = colors(idx,:);
            h.EdgeColor = 'black';
        end
        hold(ax,'off');

        if k == 1 && ~isempty(strtrim(labels.Title))
            titleText = labels.Title;
        else
            titleText = lineTitles{k};
        end
        title(ax,titleText,'Interpreter','latex');
        ax.Title.FontSize = figSettings.TitleFontSize;

        if k == 3
            if ~isempty(strtrim(labels.XLabel))
                xlabel(ax,labels.XLabel,'Interpreter','latex');
            else
                xlabel(ax,'Fracción de tensión normalizada','Interpreter','latex');
            end
            ax.XLabel.FontSize = figSettings.LabelFontSize;
        else
            xlabel(ax,'','Interpreter','latex');
        end

        if ~isempty(strtrim(labels.YLabel))
            ylabel(ax,labels.YLabel,'Interpreter','latex');
        else
            ylabel(ax,'Recuento','Interpreter','latex');
        end
        ax.YLabel.FontSize = figSettings.LabelFontSize;

        xlim(ax,[0 1]);

        if plotOpts.ShowLegend && nUseLogs > 1
            lg = legend(ax,'show','Interpreter','latex','Location','best');
            if ~isempty(lg) && isvalid(lg)
                lg.FontSize = figSettings.LegendFontSize;
            end
        else
            legend(ax,'off');
        end
    end
end

function plotHistogramGridGeneric(plotGrid,tblCell,xVar,yVars,labels,plotOpts,figSettings)

    if ~iscell(tblCell)
        tblCell = {tblCell};
    end
    nLogs = numel(tblCell);

    legendNames = buildLegendNames(plotOpts,nLogs);

    if isstring(yVars)
        yVars = cellstr(yVars);
    elseif ischar(yVars)
        yVars = {yVars};
    end
    nY = numel(yVars);

    delete(plotGrid.Children);

    if nY == 0
        plotGrid.RowHeight   = {'1x'};
        plotGrid.ColumnWidth = {'1x'};
        ax = uiaxes(plotGrid);
        ax.Layout.Row    = 1;
        ax.Layout.Column = 1;
        title(ax,'No variables selected for histogram','Interpreter','latex');
        return;
    end

    plotGrid.RowHeight   = repmat({'1x'},1,nY);
    plotGrid.ColumnWidth = {'1x'};

    colors = chooseColorScheme(figSettings.ColorScheme,max(nLogs,1));

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

        hold(ax,'on');
        anyPlotted = false;
        for j = 1:nLogs
            tbl = tblCell{j};
            if ~istable(tbl) || height(tbl)==0
                continue;
            end

            % Per-log effective range
            xRange = getEffectiveXRange(plotOpts,j);
            if ~isempty(xRange) && numel(xRange)==2 && ismember(xVar,tbl.Properties.VariableNames)
                x = tbl.(xVar);
                if isnumeric(x)
                    mask = isfinite(x) & x >= xRange(1) & x <= xRange(2);
                    tbl = tbl(mask,:);
                end
            end

            if height(tbl)==0 || ~ismember(yVars{k}, tbl.Properties.VariableNames)
                continue;
            end

            data = tbl.(yVars{k});
            data = data(~isnan(data));

            if isempty(data)
                continue;
            end

            h = histogram(ax,data, ...
                'DisplayName', legendNames{j});
            h.FaceColor = colors(j,:);
            h.EdgeColor = 'none';
            anyPlotted  = true;
        end
        hold(ax,'off');

        if k == 1 && ~isempty(strtrim(labels.Title))
            title(ax,labels.Title,'Interpreter','latex');
            ax.Title.FontSize = figSettings.TitleFontSize;
        else
            title(ax,'','Interpreter','latex');
        end

        if ~isempty(strtrim(labels.XLabel))
            xlabel(ax,labels.XLabel,'Interpreter','latex');
        else
            xlabel(ax,'','Interpreter','latex');
        end
        ax.XLabel.FontSize = figSettings.LabelFontSize;

        if ~isempty(strtrim(labels.YLabel))
            ylabel(ax,labels.YLabel,'Interpreter','latex');
        else
            ylabel(ax,'Counts','Interpreter','latex');
        end
        ax.YLabel.FontSize = figSettings.LabelFontSize;

        if plotOpts.ShowLegend && nLogs > 1 && anyPlotted
            lg = legend(ax,'show','Interpreter','latex','Location','best');
            if ~isempty(lg) && isvalid(lg)
                lg.FontSize = figSettings.LegendFontSize;
            end
        else
            legend(ax,'off');
        end

        if ~anyPlotted
            text(ax,0.5,0.5,'No numeric data for selected variable(s)', ...
                'HorizontalAlignment','center','Units','normalized');
        end
    end
end

%-------------------------------------------------------------------------%

function plotBoxplotGrid(plotGrid,tblCell,xVar,yVars,labels,plotOpts,figSettings)

    if ~iscell(tblCell)
        tblCell = {tblCell};
    end
    nLogs = numel(tblCell);

    legendNames = buildLegendNames(plotOpts,nLogs);

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

    if nY == 0
        title(ax,'No variables selected for boxplot','Interpreter','latex');
        return;
    end

    allData   = [];
    grpIdx    = [];
    grpLabels = {};
    g         = 0;

    for j = 1:nLogs
        tbl = tblCell{j};
        if ~istable(tbl) || height(tbl)==0
            continue;
        end

        % Per-log effective range
        xRange = getEffectiveXRange(plotOpts,j);
        if ~isempty(xRange) && numel(xRange)==2 && ismember(xVar,tbl.Properties.VariableNames)
            x = tbl.(xVar);
            if isnumeric(x)
                mask = isfinite(x) & x >= xRange(1) & x <= xRange(2);
                tbl = tbl(mask,:);
            end
        end

        if height(tbl)==0
            continue;
        end

        names = tbl.Properties.VariableNames;

        for k = 1:nY
            varName = yVars{k};
            if ~ismember(varName,names)
                continue;
            end
            y = tbl.(varName);
            y = y(~isnan(y));
            if isempty(y)
                continue;
            end

            g = g + 1;
            allData = [allData; y(:)];
            grpIdx  = [grpIdx; g*ones(numel(y),1)];

            if nY == 1
                % ONE VARIABLE ACROSS MULTIPLE LOGS -> label = log name
                grpLabels{g} = legendNames{j};
            else
                % Several variables: keep variable + log in the label
                grpLabels{g} = sprintf('%s (%s)', varName, legendNames{j});
            end
        end
    end

    if isempty(allData)
        title(ax,'No numeric data for selected variable(s)','Interpreter','latex');
        return;
    end

    groupCat = categorical(grpIdx,1:g,grpLabels);

    boxchart(ax,groupCat,allData);
    ax.XTickLabelRotation = 0;

    hold(ax,'on');
    for gi = 1:g
        vals = allData(grpIdx == gi);
        if isempty(vals), continue; end
        xj = gi + (rand(size(vals))-0.5)*0.15;
        scatter(ax,xj,vals,6,'r','x','MarkerEdgeAlpha',0.4);
    end
    hold(ax,'off');

% --- Title for boxplot, using 'tex' interpreter on uiaxes ---
if ~isempty(strtrim(labels.Title))
    titleStr = char(labels.Title);
else
    % Default title if user left the field empty
    titleStr = 'Comparación del Desplazamiento de Línea (\DeltaL)';
end

% If user typed LaTeX-style $...$, strip the $ for 'tex' interpreter
titleStr = strrep(titleStr,'$','');

t = title(ax, titleStr, 'Interpreter','tex');
t.FontSize = figSettings.TitleFontSize;


    if ~isempty(strtrim(labels.XLabel))
        xlabel(ax,labels.XLabel,'Interpreter','latex');
    else
        xlabel(ax,'','Interpreter','latex');
    end
    ax.XLabel.FontSize = figSettings.LabelFontSize;

    if ~isempty(strtrim(labels.YLabel))
        ylabel(ax,labels.YLabel,'Interpreter','latex');
    else
        ylabel(ax,'Value','Interpreter','latex');
    end
    ax.YLabel.FontSize = figSettings.LabelFontSize;

    legend(ax,'off');
end

%-------------------------------------------------------------------------%

function plotSingleAxes(ax,tblCell,xVar,yVars,labels,plotOpts,figSettings)

    if ~iscell(tblCell)
        tblCell = {tblCell};
    end
    nLogs = numel(tblCell);

    legendNames = buildLegendNames(plotOpts,nLogs);

    if isstring(yVars)
        yVars = cellstr(yVars);
    elseif ischar(yVars)
        yVars = {yVars};
    end

    % Map of variable-name overrides from Figure panel
    varNameMap = buildVarNameMap(plotOpts);

    %---- First pass: figure out which (log,variable) pairs actually have data
    curveList = [];  % rows [logIndex, yIndex]
    for j = 1:nLogs
        tbl = tblCell{j};
        if ~istable(tbl) || height(tbl)==0
            continue;
        end
        names = tbl.Properties.VariableNames;
        if ~ismember(xVar,names)
            continue;
        end
        x = tbl.(xVar);

        xRange_j = getEffectiveXRange(plotOpts,j);
        useRange = ~isempty(xRange_j) && numel(xRange_j)==2 && isnumeric(x);

        for k = 1:numel(yVars)
            yName = yVars{k};
            if ~ismember(yName,names)
                continue;
            end
            y = tbl.(yName);
            if ~isnumeric(y)
                continue;
            end
            good = isfinite(x) & isfinite(y);
            if useRange
                good = good & x >= xRange_j(1) & x <= xRange_j(2);
            end
            if any(good)
                curveList(end+1,:) = [j,k]; %#ok<AGROW>
            end
        end
    end

    nCurves = size(curveList,1);
    if nCurves == 0
        cla(ax);
        title(ax,'No valid data for selected variable(s) and range','Interpreter','latex');
        legend(ax,'off');
        return;
    end

    ax.FontName = figSettings.FontName;
    ax.FontSize = figSettings.TickFontSize;
    box(ax,'on');

    colors = chooseColorScheme(figSettings.ColorScheme,nCurves);

    %---- Second pass: actually plot each curve
    hold(ax,'on');
    for idx = 1:nCurves
        j = curveList(idx,1);
        k = curveList(idx,2);

        tbl = tblCell{j};
        x   = tbl.(xVar);
        y   = tbl.(yVars{k});

        xRange_j = getEffectiveXRange(plotOpts,j);

        if isnumeric(x)
            good = isfinite(x) & isfinite(y);
            if ~isempty(xRange_j) && numel(xRange_j)==2
                good = good & x >= xRange_j(1) & x <= xRange_j(2);
            end
        else
            good = isfinite(y);
        end

        xk = x(good);
        yk = y(good);
        if isempty(xk)
            continue;
        end

               color = colors(idx,:);

        % Get pretty variable name from the map (or fall back to raw name)
        varPretty = getVarLegendName(yVars{k}, varNameMap);

        if nLogs == 1
            displayName = varPretty;
        else
            % e.g. "Línea central (Kite Surf)"
            displayName = sprintf('%s (%s)', varPretty, legendNames{j});
        end


        switch figSettings.PlotStyle
            case 'linemarker'
                p = plot(ax,xk,yk,'DisplayName',displayName);
                p.Marker    = '.';
                p.LineWidth = 1.2;
                p.Color     = color;
            case 'scatter'
                scatter(ax,xk,yk,6,color,'Marker','.', ...
                    'DisplayName',displayName);
            otherwise
                p = plot(ax,xk,yk,'DisplayName',displayName);
                p.LineWidth = 1.2;
                p.Color     = color;
        end
    end
        hold(ax,'off');

    %================= NEW: enforce x-axis limits =================%
    xLimRange = [];

    % 1) Prefer explicit global X range from Plot tab
    if isfield(plotOpts,'XRangeGlobal') && ~isempty(plotOpts.XRangeGlobal)
        xLimRange = plotOpts.XRangeGlobal;

    % 2) Otherwise, if there are per-log ranges, use their union
    elseif isfield(plotOpts,'XRangePerLog') && ~isempty(plotOpts.XRangePerLog)
        per = plotOpts.XRangePerLog;
        if iscell(per)
            per = per(~cellfun(@isempty,per));
        end
        if ~isempty(per)
            mins = cellfun(@(r) r(1), per);
            maxs = cellfun(@(r) r(2), per);
            xLimRange = [min(mins) max(maxs)];
        end

    % 3) Backwards compatibility with old plotOpts.XRange
    elseif isfield(plotOpts,'XRange') && ~isempty(plotOpts.XRange)
        xLimRange = plotOpts.XRange;
    end

    if ~isempty(xLimRange) && numel(xLimRange)==2 && all(isfinite(xLimRange))
        xlim(ax,xLimRange);
    end
    %==============================================================%

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

    ax.XTickLabelRotation = 0;
end


%-------------------------------------------------------------------------%
% Helper: combine per-log and global X ranges
%-------------------------------------------------------------------------%

function xRange = getEffectiveXRange(plotOpts,j)
%GETEFFECTIVEXRANGE  Returns the [xmin xmax] to apply for log j.
% Combines:
%   - plotOpts.XRangePerLog{j}  (per-log window, from Logs menu)
%   - plotOpts.XRangeGlobal     (global X range from Plot tab)
% (and also accepts legacy plotOpts.XRange for backwards compatibility)

    xRange = [];

    % Per-log window
    if isfield(plotOpts,'XRangePerLog') && ~isempty(plotOpts.XRangePerLog)
        per = plotOpts.XRangePerLog;
        if numel(per) >= j && ~isempty(per{j})
            xRange = per{j};
        end
    end

    % Global window (new field)
    if isfield(plotOpts,'XRangeGlobal') && ~isempty(plotOpts.XRangeGlobal)
        g = plotOpts.XRangeGlobal;
        if isempty(xRange)
            xRange = g;
        else
            xRange = [max(xRange(1),g(1)), min(xRange(2),g(2))];
        end
    % Backwards compatibility with old plotOpts.XRange, if still used
    elseif isfield(plotOpts,'XRange') && ~isempty(plotOpts.XRange)
        g = plotOpts.XRange;
        if isempty(xRange)
            xRange = g;
        else
            xRange = [max(xRange(1),g(1)), min(xRange(2),g(2))];
        end
    end

    if ~isempty(xRange) && numel(xRange) >= 2 && xRange(2) < xRange(1)
        xRange = fliplr(xRange);
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
        otherwise
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

    if iscell(xVar);  xVar = xVar{1}; end
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
        xLabelStr = 'Time $t$ [s]';
    else
        xLabelStr = '';
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

%-------------------------------------------------------------------------%

function legendNames = buildLegendNames(plotOpts,nLogs)
%BUILDLEGENDNAMES  Return cellstr legend names for each log.
% Priority:
%   1) User-entered labels (comma-separated) from Figure tab
%   2) Base CSV file names
%   3) Fallback: 'Log 1', 'Log 2', ...

    % 1) Base CSV names, if available
    if isfield(plotOpts,'LogNames') && ~isempty(plotOpts.LogNames)
        logNames = plotOpts.LogNames;
    else
        logNames = cell(1,nLogs);
    end

    % 2) Normalize custom legend text (can be char, string or cell array)
    custom = '';
    if isfield(plotOpts,'LegendText') && ~isempty(plotOpts.LegendText)
        val = plotOpts.LegendText;

        % If the UI control is a text area, Value is a cell array of lines
        if iscell(val)
            % join all lines with commas so the user can enter one per line
            val = strjoin(val(:).', ',');
        elseif isstring(val)
            val = char(val);
        end

        custom = strtrim(val);
    end

    legendNames = cell(1,nLogs);

    if ~isempty(custom)
        % Split by commas and clean up
        parts = regexp(custom,',','split');
        parts = strtrim(parts);
        parts = parts(~cellfun(@isempty,parts));

        for k = 1:nLogs
            if k <= numel(parts)
                legendNames{k} = parts{k};
            elseif k <= numel(logNames) && ~isempty(logNames{k})
                legendNames{k} = logNames{k};
            else
                legendNames{k} = sprintf('Log %d',k);
            end
        end
    else
        % No custom text: fall back to CSV name or "Log k"
        for k = 1:nLogs
            if k <= numel(logNames) && ~isempty(logNames{k})
                legendNames{k} = logNames{k};
            else
                legendNames{k} = sprintf('Log %d',k);
            end
        end
    end
end

function varNameMap = buildVarNameMap(plotOpts)
%BUILDVARNAMEMAP  Parse user-defined variable legend names.
% Expected format in VarLegendText (text area):
%   ADC_LC_center = Línea central
%   ADC_LC_left   = Línea izquierda
% (one mapping per line, '=' or '->' as separator)

    varNameMap = containers.Map('KeyType','char','ValueType','char');

    if ~isfield(plotOpts,'VarLegendText') || isempty(plotOpts.VarLegendText)
        return;
    end

    val = plotOpts.VarLegendText;

    % Normalize to a single char string
    if iscell(val)
        % Join multiple lines from a text area
        val = strjoin(val(:).', sprintf('\n'));
    elseif isstring(val)
        val = char(val);
    end

    if isempty(strtrim(val))
        return;
    end

    % Split into lines
    lines = regexp(val,'[\r\n]+','split');
    for i = 1:numel(lines)
        line = strtrim(lines{i});
        if isempty(line)
            continue;
        end

        % Split on '=' or '->'
        parts = regexp(line,'=|->','split');
        if numel(parts) < 2
            continue;
        end

        rawName  = strtrim(parts{1});
        pretty   = strtrim(strjoin(parts(2:end),'=')); % in case '=' appears in RHS

        if isempty(rawName) || isempty(pretty)
            continue;
        end

        % Store mapping
        varNameMap(rawName) = pretty;
    end
end

%-------------------------------------------------------------------------%

function outName = getVarLegendName(rawName,varNameMap)
%GETVARLEGENDNAME  Return pretty name if defined, else the raw variable name.

    if isstring(rawName)
        rawName = char(rawName);
    elseif iscell(rawName)
        rawName = rawName{1};
    end

    if ~isempty(varNameMap) && isKey(varNameMap, rawName)
        outName = varNameMap(rawName);
    else
        outName = rawName;
    end
end

