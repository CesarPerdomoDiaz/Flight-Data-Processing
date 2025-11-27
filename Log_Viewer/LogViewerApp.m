classdef LogViewerApp < matlab.apps.AppBase
    % App programática: multi-serie (Fs=40 Hz), exportación, logo,
    % análisis de viento, análisis de control y análisis de actuadores.

    %----------------------------------------------------------------------
    % Componentes
    %----------------------------------------------------------------------
    properties (Access = public)
        UIFigure           matlab.ui.Figure
        LogoImage          matlab.ui.control.Image
        CargarButton       matlab.ui.control.Button
        VariablesLabel     matlab.ui.control.Label
        VariablesListBox   matlab.ui.control.ListBox
        TimeInSecondsCB    matlab.ui.control.CheckBox
        ExportFormatDD     matlab.ui.control.DropDown
        ExportButton       matlab.ui.control.Button
        UIAxes             matlab.ui.control.UIAxes
        % Menú
        MenuArchivo        matlab.ui.container.Menu
        MenuCargar         matlab.ui.container.Menu
        MenuSalir          matlab.ui.container.Menu
        MenuAnalisis       matlab.ui.container.Menu
        MenuWind           matlab.ui.container.Menu
        MenuControl        matlab.ui.container.Menu
        MenuActuadores     matlab.ui.container.Menu
    end

    %----------------------------------------------------------------------
    % Estado
    %----------------------------------------------------------------------
    properties (Access = private)
        DataStruct struct = struct();
        VarList cell = {};
        Fs double = 40;
        LogoPath char = 'logo.png';

        % Ventana de viento
        WindFig matlab.ui.Figure = matlab.ui.Figure.empty
        WindTimeAx matlab.ui.control.UIAxes
        WindHistAx matlab.ui.control.UIAxes
        WindPolarAx matlab.graphics.axis.PolarAxes

        % Ventana de control
        ControlFig matlab.ui.Figure = matlab.ui.Figure.empty
        ControlScatterAx matlab.ui.control.UIAxes
        ControlPsiAx matlab.ui.control.UIAxes

        % Ventana de actuadores
        ActFig matlab.ui.Figure = matlab.ui.Figure.empty
        ActAxes matlab.ui.control.UIAxes
        ActEnergyAx matlab.ui.control.UIAxes           % NUEVO: eje inferior energía
        ActStatsTable matlab.ui.control.Table
        ActShowTotalCB matlab.ui.control.CheckBox      % NUEVO: botón mostrar total
    end

    %----------------------------------------------------------------------
    % Callbacks
    %----------------------------------------------------------------------
    methods (Access = private)

        function startupFcn(app)
            app.refreshLogo();
        end

        function CargarButtonPushed(app, ~)
            try
                [f,p] = uigetfile({'*.csv','CSV files (*.csv)'; '*.*','All files'}, ...
                                  'Selecciona archivo log CSV');
                if isequal(f,0), return; end
                filename = fullfile(p,f);

                if exist('leer_log','file') == 2
                    data = leer_log(filename);
                else
                    data = LogViewerApp.leer_log_minimo(filename);
                end

                if ~isstruct(data)
                    uialert(app.UIFigure, 'El archivo no produjo un struct válido.', 'Error de datos');
                    return;
                end

                app.DataStruct = data;

                % Lista de variables numéricas para la vista principal
                allFields = fieldnames(data);
                isNumericField = false(size(allFields));
                for i = 1:numel(allFields)
                    v = data.(allFields{i});
                    isNumericField(i) = isnumeric(v) && ~isempty(v);
                end
                app.VarList = allFields(isNumericField);

                if ~isempty(app.VarList)
                    app.VariablesListBox.Items = app.VarList;
                    app.VariablesListBox.Value = app.VarList(1);
                else
                    app.VariablesListBox.Items = {''};
                    app.VariablesListBox.Value = {''};
                end

                app.updatePlot();            % principal
                if ~isempty(app.WindFig)    && isvalid(app.WindFig),    app.plotWindAnalysis();     end
                if ~isempty(app.ControlFig) && isvalid(app.ControlFig),  app.plotControlAnalysis();  end
                if ~isempty(app.ActFig)     && isvalid(app.ActFig),     app.plotActuatorsAnalysis();end

            catch ME
                uialert(app.UIFigure, getReport(ME,'basic','hyperlinks','off'), 'Fallo al cargar');
            end
        end

        function VariablesListBoxValueChanged(app, ~)
            app.updatePlot();
        end

        function TimeInSecondsCBValueChanged(app, ~)
            app.updatePlot();
            if ~isempty(app.ControlFig) && isvalid(app.ControlFig), app.plotControlAnalysis(); end
            if ~isempty(app.ActFig)     && isvalid(app.ActFig),     app.plotActuatorsAnalysis(); end
        end

        function ExportButtonPushed(app, ~)
            fmt = app.ExportFormatDD.Value;  % 'PNG'|'SVG'|'PDF'
            switch upper(fmt)
                case 'PNG'
                    defName = 'grafico.png';  filter = {'*.png','PNG (*.png)'};
                case 'SVG'
                    defName = 'grafico.svg';  filter = {'*.svg','SVG (*.svg)'};
                case 'PDF'
                    defName = 'grafico.pdf';  filter = {'*.pdf','PDF (*.pdf)'};
                otherwise
                    defName = 'grafico.png';  filter = {'*.png','PNG (*.png)'};
            end

            [f,p] = uiputfile(filter, 'Guardar figura como...', defName);
            if isequal(f,0), return; end
            fileout = fullfile(p,f);

            try
                switch upper(fmt)
                    case 'PNG'
                        exportgraphics(app.UIAxes, fileout, 'Resolution', 300);
                    case 'SVG'
                        exportgraphics(app.UIAxes, fileout, 'ContentType', 'vector');
                    case 'PDF'
                        exportgraphics(app.UIAxes, fileout, 'ContentType', 'vector');
                end
                uialert(app.UIFigure, ['Guardado: ' fileout], 'Éxito');
            catch ME
                uialert(app.UIFigure, getReport(ME,'basic','hyperlinks','off'), 'Error al guardar');
            end
        end

        %---------------- Menú: Archivo ----------------
        function MenuCargarSelected(app, ~, ~)
            app.CargarButtonPushed();
        end

        function MenuSalirSelected(app, ~, ~)
            delete(app.UIFigure);
            if ~isempty(app.WindFig)    && isvalid(app.WindFig),    delete(app.WindFig);    end
            if ~isempty(app.ControlFig) && isvalid(app.ControlFig), delete(app.ControlFig); end
            if ~isempty(app.ActFig)     && isvalid(app.ActFig),     delete(app.ActFig);     end
        end

        %---------------- Menú: Análisis ----------------
        function MenuWindSelected(app, ~, ~)
            app.openWindAnalysisWindow();
            app.plotWindAnalysis();
        end

        function MenuControlSelected(app, ~, ~)
            app.openControlAnalysisWindow();
            app.plotControlAnalysis();
        end

        function MenuActuadoresSelected(app, ~, ~)
            app.openActuatorsAnalysisWindow();
            app.plotActuatorsAnalysis();
        end

        %==================== Plot principal ====================
        function updatePlot(app)
            if isempty(fieldnames(app.DataStruct))
                cla(app.UIAxes); title(app.UIAxes,''); legend(app.UIAxes,'off'); return;
            end

            sel = app.VariablesListBox.Value;
            if isempty(sel)
                cla(app.UIAxes); title(app.UIAxes, 'Sin variables seleccionadas'); legend(app.UIAxes,'off'); return;
            end
            if ischar(sel), sel = {sel}; end

            cla(app.UIAxes);
            hold(app.UIAxes, 'on');

            anyPlotted = false;

            for k = 1:numel(sel)
                yName = sel{k};
                if ~isfield(app.DataStruct, yName), continue; end
                y = app.DataStruct.(yName);
                if ~isnumeric(y) || isempty(y), continue; end
                y = y(:);
                n = numel(y);

                if app.TimeInSecondsCB.Value
                    xk = (0:n-1)' / app.Fs;
                    xLabel = sprintf('Tiempo (s) — Fs=%.3g Hz', app.Fs);
                else
                    xk = (0:n-1)';
                    xLabel = 'Índice de muestra';
                end

                good = isfinite(xk) & isfinite(y);
                xk = xk(good); yk = y(good);
                if isempty(xk), continue; end

                plot(app.UIAxes, xk, yk, '-', 'LineWidth', 1.0, 'DisplayName', yName);
                anyPlotted = true;
            end

            hold(app.UIAxes, 'off');
            grid(app.UIAxes, 'on');
            xlabel(app.UIAxes, xLabel);
            ylabel(app.UIAxes, 'Valor');

            if anyPlotted
                title(app.UIAxes, 'Serie(s) (muestreo uniforme)');
                legend(app.UIAxes, 'Location','best');
            else
                title(app.UIAxes, 'No hay datos numéricos válidos para las variables seleccionadas');
                legend(app.UIAxes,'off');
            end
        end

        function refreshLogo(app)
            try
                if exist(app.LogoPath, 'file') == 2
                    app.LogoImage.ImageSource = app.LogoPath;
                else
                    app.LogoImage.ImageSource = '';
                    app.LogoImage.Tooltip = 'Coloca logo.png en el path para mostrar el logo.';
                end
            catch
            end
        end

        %================= Ventana de Análisis de Viento ===================
        function openWindAnalysisWindow(app)
            if ~isempty(app.WindFig) && isvalid(app.WindFig)
                figure(app.WindFig); return;
            end

            app.WindFig = uifigure('Name','Análisis de Viento', 'Position',[150 100 1100 650]);

            % Serie temporal (arriba)
            app.WindTimeAx = uiaxes(app.WindFig, 'Position', [50 360 1000 250]);
            title(app.WindTimeAx, 'Wind Speed vs Tiempo');
            xlabel(app.WindTimeAx, 'Tiempo'); ylabel(app.WindTimeAx, 'WIND\_speed');

            % Histograma (abajo izq)
            app.WindHistAx = uiaxes(app.WindFig, 'Position', [50 50 480 260]);
            title(app.WindHistAx, 'Distribución de WIND\_speed');
            xlabel(app.WindHistAx, 'WIND\_speed'); ylabel(app.WindHistAx, 'Cuenta');

            % Polar (abajo dcha)
            app.WindPolarAx = polaraxes('Parent', app.WindFig);
            set(app.WindPolarAx, 'Units','normalized', 'Position',[0.62 0.08 0.34 0.40]);
            title(app.WindPolarAx, 'Rosa (dirección/velocidad)');
            thetalim(app.WindPolarAx, [0 360]);
            rtickformat(app.WindPolarAx, '%.0f');
            app.WindPolarAx.ThetaZeroLocation = 'top';
            app.WindPolarAx.ThetaDir = 'clockwise';
            thetaticks(app.WindPolarAx, 0:45:315);
            thetaticklabels(app.WindPolarAx, {'N','NE','E','SE','S','SW','W','NW'});
        end

        function plotWindAnalysis(app)
            if isempty(app.WindFig) || ~isvalid(app.WindFig), return; end
            if ~isfield(app.DataStruct,'WIND_speed') || ~isfield(app.DataStruct,'WIND_direction')
                uialert(app.WindFig, 'Faltan campos WIND\_speed o WIND\_direction en los datos.', 'Datos insuficientes');
                return;
            end

            ws = app.DataStruct.WIND_speed(:);
            wd = app.DataStruct.WIND_direction(:);
            good = isfinite(ws) & isfinite(wd);
            ws = ws(good); wd = wd(good);

            if isempty(ws)
                cla(app.WindTimeAx); cla(app.WindHistAx); cla(app.WindPolarAx);
                title(app.WindTimeAx,'Sin datos válidos'); title(app.WindHistAx,''); title(app.WindPolarAx,'');
                return;
            end

            % 1) Serie temporal
            t = (0:numel(ws)-1)'/app.Fs;
            cla(app.WindTimeAx);
            plot(app.WindTimeAx, t, ws, '-', 'LineWidth', 1);
            grid(app.WindTimeAx,'on');
            xlabel(app.WindTimeAx, sprintf('Tiempo (s) — Fs=%.3g Hz', app.Fs));
            ylabel(app.WindTimeAx, 'WIND\_speed');

            % 2) Histograma
            cla(app.WindHistAx);
            histogram(app.WindHistAx, ws, 'BinMethod','fd');
            grid(app.WindHistAx,'on');
            xlabel(app.WindHistAx, 'WIND\_speed'); ylabel(app.WindHistAx, 'Cuenta');

            % 3) Polar (scatter por rangos)
            cla(app.WindPolarAx); hold(app.WindPolarAx,'on');
            theta = deg2rad(wd);
            mask1 = ws <= 5;
            mask2 = ws > 5  & ws <= 10;
            mask3 = ws > 10 & ws <= 15;
            mask4 = ws > 15;

            if any(mask1), polarscatter(app.WindPolarAx, theta(mask1), ws(mask1), 12, 'filled', ...
                    'MarkerFaceColor',[0 0 1], 'MarkerEdgeColor','k', 'DisplayName','<=5'); end
            if any(mask2), polarscatter(app.WindPolarAx, theta(mask2), ws(mask2), 12, 'filled', ...
                    'MarkerFaceColor',[1 1 0], 'MarkerEdgeColor','k', 'DisplayName','5-10'); end
            if any(mask3), polarscatter(app.WindPolarAx, theta(mask3), ws(mask3), 12, 'filled', ...
                    'MarkerFaceColor',[0 0.6 0], 'MarkerEdgeColor','k', 'DisplayName','10-15'); end
            if any(mask4), polarscatter(app.WindPolarAx, theta(mask4), ws(mask4), 12, 'filled', ...
                    'MarkerFaceColor',[1 0 0], 'MarkerEdgeColor','k', 'DisplayName','>15'); end

            thetalim(app.WindPolarAx, [0 360]); rtick(app.WindPolarAx, 'auto');
            grid(app.WindPolarAx,'on');
            legend(app.WindPolarAx, 'Location','northeastoutside', 'Title','Wind Speed (m/s)');
            hold(app.WindPolarAx,'off');
        end

        %================= Ventana de Análisis de Control ===========
        function openControlAnalysisWindow(app)
            if ~isempty(app.ControlFig) && isvalid(app.ControlFig)
                figure(app.ControlFig); return;
            end

            app.ControlFig = uifigure('Name','Análisis de control', 'Position',[200 120 1000 700]);

            % Scatter phi (x) vs beta (y) arriba
            app.ControlScatterAx = uiaxes(app.ControlFig, 'Position', [60 400 880 250]);
            title(app.ControlScatterAx, '\phi vs \beta (scatter)');
            xlabel(app.ControlScatterAx, '\phi'); ylabel(app.ControlScatterAx, '\beta'); grid(app.ControlScatterAx,'on');

            % Serie psi vs psi_set abajo
            app.ControlPsiAx = uiaxes(app.ControlFig, 'Position', [60 80 880 250]);
            title(app.ControlPsiAx, '\psi y \psi_{set} vs tiempo');
            xlabel(app.ControlPsiAx, 'Tiempo (s)'); ylabel(app.ControlPsiAx, '\psi'); grid(app.ControlPsiAx,'on');
            legend(app.ControlPsiAx,'off');
        end

        function plotControlAnalysis(app)
            if isempty(app.ControlFig) || ~isvalid(app.ControlFig), return; end

            havePhi  = isfield(app.DataStruct,'CONTROL_phi');
            haveBeta = isfield(app.DataStruct,'CONTROL_beta');
            havePsi  = isfield(app.DataStruct,'CONTROL_psi');
            havePsiS = isfield(app.DataStruct,'CONTROL_psi_set');

            % --- Scatter phi vs beta ---
            cla(app.ControlScatterAx);
            if havePhi && haveBeta
                phi  = app.DataStruct.CONTROL_phi(:);
                beta = app.DataStruct.CONTROL_beta(:);
                good = isfinite(phi) & isfinite(beta);
                phi  = phi(good); beta = beta(good);
                if ~isempty(phi)
                    scatter(app.ControlScatterAx, phi, beta, 10, 'filled');
                else
                    text(app.ControlScatterAx,0.5,0.5,'Sin datos válidos','HorizontalAlignment','center','Units','normalized');
                end
            else
                text(app.ControlScatterAx,0.5,0.5,'Faltan CONTROL\_phi o CONTROL\_beta','HorizontalAlignment','center','Units','normalized');
            end
            grid(app.ControlScatterAx,'on');

            % --- psi y psi_set vs tiempo ---
            cla(app.ControlPsiAx);
            if havePsi && havePsiS
                psi    = app.DataStruct.CONTROL_psi(:);
                psiSet = app.DataStruct.CONTROL_psi_set(:);

                n = min(numel(psi), numel(psiSet));
                psi = psi(1:n); psiSet = psiSet(1:n);

                t = (0:n-1)'/app.Fs;
                good = isfinite(t) & isfinite(psi) & isfinite(psiSet);
                t = t(good); psi = psi(good); psiSet = psiSet(good);

                if ~isempty(t)
                    hold(app.ControlPsiAx,'on');
                    plot(app.ControlPsiAx, t, psi, '-', 'LineWidth', 1.1, 'DisplayName','\psi');
                    plot(app.ControlPsiAx, t, psiSet, '-', 'LineWidth', 1.1, 'DisplayName','\psi_{set}');
                    hold(app.ControlPsiAx,'off');
                    legend(app.ControlPsiAx,'Location','best');
                else
                    text(app.ControlPsiAx,0.5,0.5,'Sin datos válidos','HorizontalAlignment','center','Units','normalized');
                    legend(app.ControlPsiAx,'off');
                end
            else
                text(app.ControlPsiAx,0.5,0.5,'Faltan CONTROL\_psi o CONTROL\_psi\_set','HorizontalAlignment','center','Units','normalized');
                legend(app.ControlPsiAx,'off');
            end
            xlabel(app.ControlPsiAx, sprintf('Tiempo (s) — Fs=%.3g Hz', app.Fs));
            ylabel(app.ControlPsiAx, '\psi');
            grid(app.ControlPsiAx,'on');
        end

        %================= Ventana Análisis Actuadores ==============
        function openActuatorsAnalysisWindow(app)
            if ~isempty(app.ActFig) && isvalid(app.ActFig)
                figure(app.ActFig); return;
            end

            % Ventana más ancha para dar más espacio a la tabla derecha
            app.ActFig = uifigure('Name','Análisis actuadores', 'Position',[220 100 1200 720]);

            % Checkbox para mostrar potencia total
            app.ActShowTotalCB = uicheckbox(app.ActFig, ...
                'Text','Mostrar potencia total (P10+P20+P21+P30)', ...
                'Value', false, ...
                'Position', [40 685 400 22], ...
                'ValueChangedFcn', @(~,~) app.plotActuatorsAnalysis());

            % Eje superior: Potencia de los 4 actuadores
            app.ActAxes = uiaxes(app.ActFig, 'Position', [40 380 820 290]);
            title(app.ActAxes, 'Potencia actuadores (W)');
            xlabel(app.ActAxes, 'Tiempo (s)'); ylabel(app.ActAxes, 'Potencia (W)');
            grid(app.ActAxes, 'on');

            % Eje inferior: Energía acumulada
            app.ActEnergyAx = uiaxes(app.ActFig, 'Position', [40 80 820 260]);
            title(app.ActEnergyAx, 'Energía consumida por los actuadores (Wh)');
            xlabel(app.ActEnergyAx, 'Tiempo (s)'); ylabel(app.ActEnergyAx, 'Energía (J)');
            grid(app.ActEnergyAx, 'on');

            % Tabla de estadísticas a la derecha (más ancha)
            app.ActStatsTable = uitable(app.ActFig, ...
                'Position', [880 80 300 590], ...
                'ColumnName', {'Variable','Mín','Máx','Media'}, ...
                'ColumnEditable', [false false false false], ...
                'ColumnWidth', {80, 70, 70, 80}, ...
                'Data', cell(0,4));
            % Strings formateados (sin notación científica)
            app.ActStatsTable.ColumnFormat = {'char','char','char','char'};
        end

        function plotActuatorsAnalysis(app)
            if isempty(app.ActFig) || ~isvalid(app.ActFig), return; end

            need = {'DPRO_10_current','DPRO_20_current','DPRO_21_current','DPRO_30_current','DPRO_voltage_48'};
            hasAll = all(isfield(app.DataStruct, need));
            cla(app.ActAxes); cla(app.ActEnergyAx);
            app.ActStatsTable.Data = cell(0,4);

            if ~hasAll
                text(app.ActAxes,0.5,0.5,'Faltan DPRO\_xx\_current o DPRO\_voltage\_48','HorizontalAlignment','center','Units','normalized');
                text(app.ActEnergyAx,0.5,0.5,'Sin datos','HorizontalAlignment','center','Units','normalized');
                return;
            end

            % Tomar datos (como en tu versión)
            i10 = app.DataStruct.DPRO_10_current(:);
            i20 = app.DataStruct.DPRO_20_current(:);
            i21 = app.DataStruct.DPRO_21_current(:);
            i30 = app.DataStruct.DPRO_30_current(:);
            v48 = app.DataStruct.DPRO_voltage_48(:);

            % Igualar longitudes
            n = min([numel(i10), numel(i20), numel(i21), numel(i30), numel(v48)]);
            i10 = i10(1:n); i20 = i20(1:n); i21 = i21(1:n); i30 = i30(1:n); v48 = v48(1:n);

            % Potencias (W): P = I * V / 1e6  (mantengo tu escala y signo)
            P10 = (i10 .* v48) / 1000000;
            P20 = (i20 .* v48) / 1000000;
            P21 = -(i21 .* v48) / 1000000; % CAMBIO SIGNO PARA AJUSTAR AL SENTIDO
            P30 = (i30 .* v48) / 1000000;

            % Filtrar no-finitos en bloque
            t = (0:n-1)'/app.Fs;
            good = isfinite(t) & isfinite(P10) & isfinite(P20) & isfinite(P21) & isfinite(P30);
            t = t(good); P10 = P10(good); P20 = P20(good); P21 = P21(good); P30 = P30(good);

            if isempty(t)
                text(app.ActAxes,0.5,0.5,'Sin datos válidos','HorizontalAlignment','center','Units','normalized');
                text(app.ActEnergyAx,0.5,0.5,'Sin datos válidos','HorizontalAlignment','center','Units','normalized');
                return;
            end

            % -------- Plot superior: Potencias individuales (+ opcional total) ----------
            hold(app.ActAxes,'on');
            plot(app.ActAxes, t, P10, '-', 'LineWidth', 1.1, 'DisplayName','P10 (W)');
            plot(app.ActAxes, t, P20, '-', 'LineWidth', 1.1, 'DisplayName','P20 (W)');
            plot(app.ActAxes, t, P21, '-', 'LineWidth', 1.1, 'DisplayName','P21 (W)');
            plot(app.ActAxes, t, P30, '-', 'LineWidth', 1.1, 'DisplayName','P30 (W)');

            Psum = P10 + P20 + P21 + P30;
            if ~isempty(app.ActShowTotalCB) && isvalid(app.ActShowTotalCB) && app.ActShowTotalCB.Value
                plot(app.ActAxes, t, Psum, '-', 'LineWidth', 1.8, 'Color',[0 0 0], 'DisplayName','P_{tot} (W)');
            end
            hold(app.ActAxes,'off');
            legend(app.ActAxes,'Location','best');
            xlabel(app.ActAxes, sprintf('Tiempo (s) — Fs=%.3g Hz', app.Fs));
            ylabel(app.ActAxes, 'Potencia (W)');
            grid(app.ActAxes,'on');

            % Sin notación científica en Y (potencia)
            try, ytickformat(app.ActAxes,'%.0f'); end
            try, app.ActAxes.YRuler.Exponent = 0; end

            % -------- Plot inferior: Energía acumulada de Psum (Wh) ----------
            dt = 1/app.Fs;
            Ewh = cumsum(Psum) * dt / 3600;   % W*s / 3600 = Wh
            
            % Colorear por signo de Psum: rojo (>=0), verde (<0)
            Ewh_pos = Ewh; Ewh_pos(Psum < 0)  = NaN;
            Ewh_neg = Ewh; Ewh_neg(Psum >= 0) = NaN;
            
            hold(app.ActEnergyAx,'on');
            plot(app.ActEnergyAx, t, Ewh_pos, '.', 'LineWidth', 0.5, 'Color',[1 0 0],   'DisplayName','E (+P) [Wh]');
            plot(app.ActEnergyAx, t, Ewh_neg, '.', 'LineWidth', 0.5, 'Color',[0 0.6 0], 'DisplayName','E (-P) [Wh]');
            hold(app.ActEnergyAx,'off');
            legend(app.ActEnergyAx,'Location','best');
            title(app.ActEnergyAx, 'Energía consumida por los actuadores (Wh)');
            xlabel(app.ActEnergyAx, sprintf('Tiempo (s) — Fs=%.3g Hz', app.Fs));
            ylabel(app.ActEnergyAx, 'Energía (Wh)');
            grid(app.ActEnergyAx,'on');
            
            % Sin notación científica en Y (energía)
            try, ytickformat(app.ActEnergyAx,'%.0f'); end
            try, app.ActEnergyAx.YRuler.Exponent = 0; end


            % -------- Tabla: min, max, mean como STRING (sin 'e') --------
            stats = @(x) [min(x), max(x), mean(x)];
            s10 = stats(P10); s20 = stats(P20); s21 = stats(P21); s30 = stats(P30);

            fmt = @(x) sprintf('%.0f', x);  % sin notación científica
            app.ActStatsTable.Data = {
                'P10', fmt(s10(1)), fmt(s10(2)), fmt(s10(3));
                'P20', fmt(s20(1)), fmt(s20(2)), fmt(s20(3));
                'P21', fmt(s21(1)), fmt(s21(2)), fmt(s21(3));
                'P30', fmt(s30(1)), fmt(s30(2)), fmt(s30(3));
            };
        end
    end

    %----------------------------------------------------------------------
    % Creación de componentes (UI programática)
    %----------------------------------------------------------------------
    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Visible','off');
            app.UIFigure.Position = [100 100 1100 640];
            app.UIFigure.Name = 'Log Viewer';

            %==================== MENÚ SUPERIOR ====================
            app.MenuArchivo = uimenu(app.UIFigure, 'Text','Archivo');
            app.MenuCargar  = uimenu(app.MenuArchivo, 'Text','Cargar CSV', ...
                'MenuSelectedFcn', @(src,evt) app.MenuCargarSelected(src,evt));
            app.MenuSalir   = uimenu(app.MenuArchivo, 'Text','Salir', ...
                'MenuSelectedFcn', @(src,evt) app.MenuSalirSelected(src,evt));

            app.MenuAnalisis = uimenu(app.UIFigure, 'Text','Análisis');
            app.MenuWind     = uimenu(app.MenuAnalisis, 'Text','Análisis de viento', ...
                'MenuSelectedFcn', @(src,evt) app.MenuWindSelected(src,evt));
            app.MenuControl  = uimenu(app.MenuAnalisis, 'Text','Análisis de control', ...
                'MenuSelectedFcn', @(src,evt) app.MenuControlSelected(src,evt));
            app.MenuActuadores = uimenu(app.MenuAnalisis, 'Text','Análisis actuadores', ...
                'MenuSelectedFcn', @(src,evt) app.MenuActuadoresSelected(src,evt));

            %====================== CABECERA =======================
            app.LogoImage = uiimage(app.UIFigure);
            app.LogoImage.Position = [18 578 110 38];
            app.LogoImage.ScaleMethod = 'fit';

            app.CargarButton = uibutton(app.UIFigure, 'push', ...
                'Text','Cargar CSV', 'Position',[140 580 110 28], ...
                'ButtonPushedFcn', @(~,~) app.CargarButtonPushed());

            % Exportación
            app.ExportFormatDD = uidropdown(app.UIFigure, ...
                'Items', {'PNG','SVG','PDF'}, 'Value', 'PNG', 'Position', [140 542 80 26]);
            app.ExportButton = uibutton(app.UIFigure, 'push', ...
                'Text','Guardar', 'Position',[230 542 80 26], ...
                'ButtonPushedFcn', @(~,~) app.ExportButtonPushed());

            app.VariablesLabel = uilabel(app.UIFigure, 'Text','Variables:', 'Position',[270 583 70 22]);

            app.VariablesListBox = uilistbox(app.UIFigure, ...
                'Position',[345 540 300 70], 'Multiselect','on', 'Items', {''}, ...
                'ValueChangedFcn', @(~,~) app.VariablesListBoxValueChanged());

            app.TimeInSecondsCB = uicheckbox(app.UIFigure, ...
                'Text','Tiempo en segundos (Fs=40 Hz, t = (0:n-1)/Fs)', ...
                'Position',[665 583 320 22], 'Value', true, ...
                'ValueChangedFcn', @(~,~) app.TimeInSecondsCBValueChanged());

            % Área central (solo gráfico principal)
            app.UIAxes = uiaxes(app.UIFigure);
            app.UIAxes.Position = [20 20 1060 500];
            title(app.UIAxes, 'Serie(s) (muestreo uniforme)');
            xlabel(app.UIAxes, 'Tiempo'); ylabel(app.UIAxes, 'Valor'); grid(app.UIAxes,'on');

            app.UIFigure.Visible = 'on';
        end
    end

    %----------------------------------------------------------------------
    % Inicialización
    %----------------------------------------------------------------------
    methods (Access = public)
        function app = LogViewerApp
            createComponents(app);
            runStartupFcn(app, @startupFcn);
        end
    end

    %----------------------------------------------------------------------
    % Utilidad: lector mínimo si no está en el path (tolerante a texto)
    %----------------------------------------------------------------------
    methods (Static, Access = private)
        function data = leer_log_minimo(filename)
            C = readcell(filename, 'Delimiter', ',', 'NumHeaderLines', 0);
            nCols = size(C,2);

            varNames = { ...
                'CONTROL_timestamp_us','PX_time_boot_ms','PX_time_unix_usec', ...
                'PX_pos_time_boot_ms','Extracol','PX_x','PX_y','PX_z', ...
                'PX_vx','PX_vy','PX_vz','PX_att_time_boot_ms','PX_qw','PX_qx', ...
                'PX_qy','PX_qz','PX_rollspeed','PX_pitchspeed','PX_yawspeed', ...
                'PX_GPS_time_unix_usec','PX_GPS_latitude','PX_GPS_longitude', ...
                'PX_GPS_altMSL','PX_GPS_cog','PX_fixType','PX_GPS_hacc', ...
                'PX_GPS_vacc','PX_voltage_battery','PX_battery_remaining', ...
                'PX_drop_rate_comm','ADC_AIR_us','ADC_AIR_LC1','ADC_AIR_LC2', ...
                'ADC_AIR_LC3','ADC_LC_1','ADC_LC_2','ADC_LC_3','ADC_LC_left', ...
                'ADC_LC_center','ADC_LC_right','ENCODER_H','ENCODER_V', ...
                'WIND_time_boot_ms','WIND_speed','WIND_direction','GPS_meanAccuracy', ...
                'GPS_duration','GPS_flags','DPRO_voltage_48','DPRO_10_position', ...
                'DPRO_10_velocity','DPRO_20_position','DPRO_20_velocity', ...
                'DPRO_21_position','DPRO_21_velocity','DPRO_30_position', ...
                'DPRO_30_velocity','DPRO_10_current','DPRO_20_current', ...
                'DPRO_21_current','DPRO_30_current','WINCH_speed','ADC_X', ...
                'ADC_Y','ADC_T','ADC_K','PIN_1','PIN_2','PIN_up','PIN_down', ...
                'CONTROL_launch_px2gcu_coordinates_x','CONTROL_launch_px2gcu_coordinates_y', ...
                'CONTROL_launch_px2gcu_coordinates_z','CONTROL_launch_px_coordinates_x', ...
                'CONTROL_launch_px_coordinates_y','CONTROL_launch_px_coordinates_z', ...
                'CONTROL_phi','CONTROL_beta','CONTROL_psi','CONTROL_psi_set', ...
                'CONTROL_PID_kp','CONTROL_PID_ki','CONTROL_PID_kd','CONTROL_PID_e_k', ...
                'CONTROL_PID_e_i','CONTROL_PID_e_d','CONTROL_deltaL','CONTROL_thirdLineDeltaL', ...
                'CONTROL_guidanceMode','CONTROL_foeState','CONTROL_tetherLength', ...
                'CONTROL_beta_set','CONTROL_PID_pitch_kp','CONTROL_PID_pitch_ki', ...
                'CONTROL_PID_pitch_kd','CONTROL_PID_pitch_e_k','CONTROL_PID_pitch_e_i', ...
                'CONTROL_PID_pitch_e_d'};

            if nCols > numel(varNames)
                for i = numel(varNames)+1:nCols
                    varNames{end+1} = sprintf('extra_col_%d', i);
                end
            else
                varNames = varNames(1:nCols);
            end

            for i = 1:nCols
                col = C(:,i);
                num = str2double(string(col));
                if all(isnan(num)) && ~all(cellfun(@isempty,col))
                    data.(varNames{i}) = string(col(:));
                else
                    data.(varNames{i}) = num(:);
                end
            end

            % Calibración celdas de carga (igual que antes)
            fc_LC_left   = 1.07; fc_LC_center = 1.04; fc_LC_right  = 1.08;
            if isfield(data,'ADC_LC_1') && isfield(data,'ADC_LC_2') && isfield(data,'ADC_LC_3')
                data.LC_left   = double(data.ADC_LC_1) ./ 4096 * 100 * fc_LC_left   * 9.81;
                data.LC_center = double(data.ADC_LC_2) ./ 4096 * 200 * fc_LC_center * 9.81;
                data.LC_right  = double(data.ADC_LC_3) ./ 4096 * 100 * fc_LC_right  * 9.81;
            else
                data.LC_left   = [];
                data.LC_center = [];
                data.LC_right  = [];
            end
        end
    end
end
