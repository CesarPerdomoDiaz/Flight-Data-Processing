%% ========================================================================
%  1. CONFIGURACIÓN INICIAL
%  ========================================================================
clear; clc; close all;
% Factores de corrección de las células de carga (constantes)
fc_LC_left = 1.07;
fc_LC_center = 1.04;
fc_LC_right = 1.08;
radius = 0.025; % Pulley radius (m)
m_per_inc = (1/60)*(1/29.4)*0.220;

% Parámetros de adquisición de datos
fs = 40;      % Frecuencia de adquisición (Hz)
dt = 1/fs;    % Periodo de muestreo (s)

%% ========================================================================
%  2. EXTRACCIÓN Y PROCESADO DE DATOS
%  ========================================================================
% --- Archivo 1: NASA 5m2 ---
data_nasa = leer_log("log01_nasa_5m2.csv");
LC_left = data_nasa.ADC_LC_1/4096*100*fc_LC_left*9.81;
LC_center = data_nasa.ADC_LC_2/4096*200*fc_LC_center*9.81;
LC_right = data_nasa.ADC_LC_3/4096*100*fc_LC_right*9.81;
sum_LC_nasa = LC_left + LC_center + LC_right;
delta_T_nasa = LC_left - LC_right;
deltaL_nasa = data_nasa.CONTROL_deltaL;
deriv_deltaL_nasa = diff(deltaL_nasa) / dt; % Se divide por dt para obtener m/s
LC_left_nasa = LC_left;
LC_center_nasa = LC_center;
LC_right_nasa = LC_right;
% Normalización de la tensión (NASA)
norm_LC_left_nasa = LC_left./sum_LC_nasa;
norm_LC_center_nasa = LC_center./sum_LC_nasa;
norm_LC_right_nasa = LC_right./sum_LC_nasa;

% --- Archivo 2: Kitesurf 10m2 ---
data_kitesurf = leer_log("log08_kitesurf.csv");
LC_left = data_kitesurf.ADC_LC_1/4096*100*fc_LC_left*9.81;
LC_center = data_kitesurf.ADC_LC_2/4096*200*fc_LC_center*9.81;
LC_right = data_kitesurf.ADC_LC_3/4096*100*fc_LC_right*9.81;
sum_LC_kitesurf = LC_left + LC_center + LC_right;
delta_T_kitesurf = LC_left - LC_right;
deltaL_kitesurf = data_kitesurf.CONTROL_deltaL;
% --- Filtrado y Derivada (en m/s) ---
deriv_deltaL_kitesurf = diff(deltaL_kitesurf) / dt; % Se divide por dt para obtener m/s
% Normalización de la tensión (Kitesurf)
norm_LC_left_kitesurf = LC_left./sum_LC_kitesurf;
norm_LC_center_kitesurf = LC_center./sum_LC_kitesurf;
norm_LC_right_kitesurf = LC_right./sum_LC_kitesurf;

% --- Archivo 3: Delta ---
data_delta = leer_log("log04_delta.csv");
LC_left = data_delta.ADC_LC_1/4096*100*fc_LC_left*9.81;
LC_center = data_delta.ADC_LC_2/4096*200*fc_LC_center*9.81;
LC_right = data_delta.ADC_LC_3/4096*100*fc_LC_right*9.81;
sum_LC_delta = LC_left + LC_center + LC_right;
delta_T_delta = LC_left - LC_right;
deltaL_delta = data_delta.CONTROL_deltaL;
% --- Filtrado y Derivada (en m/s) ---

deriv_deltaL_delta = diff(deltaL_delta) / dt; % Se divide por dt para obtener m/s
% Normalización de la tensión (Delta)
norm_LC_left_delta = LC_left./sum_LC_delta;
norm_LC_center_delta = LC_center./sum_LC_delta;
norm_LC_right_delta = LC_right./sum_LC_delta;

%% ========================================================================
%  3. GENERACIÓN DE GRÁFICAS (Sin LaTeX)
%  ========================================================================
% --- Figura 1: Tensión de las líneas (NASA 5m2) ---
figure(1);
t_nasa = (0:length(LC_left_nasa)-1) * dt; % Vector de tiempo para NASA
plot(t_nasa, LC_right_nasa, 'k:', 'LineWidth', 1.2, 'DisplayName', 'Línea derecha');
hold on;
plot(t_nasa, LC_center_nasa, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Línea central');
plot(t_nasa, LC_left_nasa, 'k-', 'LineWidth', 1.2, 'DisplayName', 'Línea izquierda');
hold off;
title('Tensión de las líneas (NASA 5m2)', 'FontWeight', 'bold', 'FontSize', 14);
xlabel('Tiempo (s)', 'FontSize', 12); % Eje X en segundos
ylabel('Tensión (N)', 'FontSize', 12);
legend('show', 'Location', 'best', 'FontSize', 10);
grid on;

% --- Figura 4: Distribución de tensión normalizada (Delta) ---
figure(4);
subplot(3,1,1);
histogram(norm_LC_center_delta);
xlim([0 1]);
title('Línea central', 'FontSize', 10);
subplot(3,1,2);
histogram(norm_LC_left_delta);
xlim([0 1]);
title('Línea izquierda', 'FontSize', 10);
subplot(3,1,3);
histogram(norm_LC_right_delta);
xlim([0 1]);
title('Línea derecha', 'FontSize', 10);
sgtitle('Distribución de Tensión Normalizada (Delta)', 'FontWeight', 'bold', 'FontSize', 14);

% --- Figura 5: Distribución de tensión normalizada (NASA 5m2) ---
figure(5);
subplot(3,1,1);
histogram(norm_LC_center_nasa);
xlim([0 1]);
title('Línea central', 'FontSize', 10);
subplot(3,1,2);
histogram(norm_LC_left_nasa);
xlim([0 1]);
title('Línea izquierda', 'FontSize', 10);
subplot(3,1,3);
histogram(norm_LC_right_nasa);
xlim([0 1]);
title('Línea derecha', 'FontSize', 10);
sgtitle('Distribución de Tensión Normalizada (NASA 5m2)', 'FontWeight', 'bold', 'FontSize', 14);

% --- Figura 6: Distribución de tensión normalizada (Kitesurf 10m2) ---
figure(6);
subplot(3,1,1);
histogram(norm_LC_center_kitesurf);
xlim([0 1]);
title('Línea central', 'FontSize', 10);
subplot(3,1,2);
histogram(norm_LC_left_kitesurf);
xlim([0 1]);
title('Línea izquierda', 'FontSize', 10);
subplot(3,1,3);
histogram(norm_LC_right_kitesurf);
xlim([0 1]);
title('Línea derecha', 'FontSize', 10);
sgtitle('Distribución de Tensión Normalizada (Kitesurf 10m2)', 'FontWeight', 'bold', 'FontSize', 14);

% --- Figura 8: Boxplot comparativo de Diferencia de Tensión ---
figure(8);
datos_delta_T = [delta_T_delta(:); delta_T_nasa(:); delta_T_kitesurf(:)];
grupos_delta_T_str = [repmat({'Delta'}, length(delta_T_delta), 1); ...
                      repmat({'NASA 5m2'}, length(delta_T_nasa), 1); ...
                      repmat({'Kitesurf 10m2'}, length(delta_T_kitesurf), 1)];
orden_deseado_8 = {'Delta', 'NASA 5m2', 'Kitesurf 10m2'};
grupos_ordenados_8 = categorical(grupos_delta_T_str, orden_deseado_8);
boxplot(datos_delta_T, grupos_ordenados_8);
title('Comparación de Diferencia de Tensión (\DeltaF)', 'FontWeight', 'bold', 'FontSize', 14);
ylabel('\DeltaF (N)', 'FontSize', 12);
grid on;

% --- Figura 9: Boxplot comparativo de Tensión Total ---
figure(9);
datos_sum_LC = [sum_LC_delta(:); sum_LC_nasa(:); sum_LC_kitesurf(:)];
grupos_sum_LC_str = [repmat({'Delta'}, length(sum_LC_delta), 1); ...
                     repmat({'NASA 5m2'}, length(sum_LC_nasa), 1); ...
                     repmat({'Kitesurf 10m2'}, length(sum_LC_kitesurf), 1)];
orden_deseado_9 = {'Delta', 'NASA 5m2', 'Kitesurf 10m2'};
grupos_ordenados_9 = categorical(grupos_sum_LC_str, orden_deseado_9);
boxplot(datos_sum_LC, grupos_ordenados_9);
title('Comparación de la Tensión Total en las Líneas', 'FontWeight', 'bold', 'FontSize', 14);
ylabel('Suma de Tensiones (N)', 'FontSize', 12);
grid on;

% --- Figura 10: Boxplot comparativo de Desplazamiento de Línea ---
figure(10);
datos_deltaL = [deltaL_delta(:); deltaL_nasa(:); deltaL_kitesurf(:)];
grupos_deltaL_str = [repmat({'Delta'}, length(deltaL_delta), 1); ...
                     repmat({'NASA 5m2'}, length(deltaL_nasa), 1); ...
                     repmat({'Kitesurf 10m2'}, length(deltaL_kitesurf), 1)];
orden_deseado_10 = {'Delta', 'NASA 5m2', 'Kitesurf 10m2'};
grupos_ordenados_10 = categorical(grupos_deltaL_str, orden_deseado_10);
boxplot(datos_deltaL, grupos_ordenados_10);
title('Comparación del Desplazamiento de Línea (\DeltaL)', 'FontWeight', 'bold', 'FontSize', 14);
ylabel('Desplazamiento (m)', 'FontSize', 12);
grid on;

%% --- Figura 11: Plot comparativo de la Velocidad de Desplazamiento ---
figure(11);


% Calcular los vectores de velocidad originales
v_delta = 2*m_per_inc*(data_delta.DPRO_20_velocity);
v_kitesurf = 2*m_per_inc*(data_kitesurf.DPRO_20_velocity);
v_nasa = 2*m_per_inc*(data_nasa.DPRO_20_velocity);

% --- 1. Filtrado de datos para mantener el 95% central ---

% Para v_delta
p_delta = prctile(v_delta, [5, 95]);
v_delta_filt = v_delta(v_delta >= p_delta(1) & v_delta <= p_delta(2));

% Para v_nasa
p_nasa = prctile(v_nasa, [5, 95]);
v_nasa_filt = v_nasa(v_nasa >= p_nasa(1) & v_nasa <= p_nasa(2));

% Para v_kitesurf
p_kitesurf = prctile(v_kitesurf, [5, 95]);
v_kitesurf_filt = v_kitesurf(v_kitesurf >= p_kitesurf(1) & v_kitesurf <= p_kitesurf(2));


% --- 2. Código para el Boxplot con datos filtrados ---

% Combinar los vectores de velocidad ya filtrados
all_velocities_filt = [v_delta_filt; v_nasa_filt; v_kitesurf_filt];

% Crear la variable de agrupación (usando el tamaño de los nuevos vectores)
group_labels_filt = [repmat({'Delta'}, length(v_delta_filt), 1); ...
                     repmat({'NASA 5m2'}, length(v_nasa_filt), 1); ...
                     repmat({'Kitesurf 10m2'}, length(v_kitesurf_filt), 1)];

% Crear el boxplot con los datos limpios
boxplot(all_velocities_filt, group_labels_filt);

% Añadir títulos y etiquetas
title('Distribución de la Velocidad (95% central)', 'FontWeight', 'bold', 'FontSize', 14);
ylabel('Velocidad (m/s)', 'FontSize', 12);
ylim([-1,1])
grid on;
%% ========================================================================
%  4. GUARDADO DE GRÁFICAS
%  ========================================================================
disp('Guardando gráficas como PDF...');
% Guardar Figura 1
exportgraphics(figure(1), 'Tension_Lineas_NASA.pdf', 'ContentType', 'vector');
% Guardar Figura 4
exportgraphics(figure(4), 'Distribucion_Tension_Normalizada_Delta.pdf', 'ContentType', 'vector');
% Guardar Figura 5
exportgraphics(figure(5), 'Distribucion_Tension_Normalizada_NASA.pdf', 'ContentType', 'vector');
% Guardar Figura 6
exportgraphics(figure(6), 'Distribucion_Tension_Normalizada_Kitesurf.pdf', 'ContentType', 'vector');
% Guardar Figura 8
exportgraphics(figure(8), 'Boxplot_Diferencia_Tension.pdf', 'ContentType', 'vector');
% Guardar Figura 9
exportgraphics(figure(9), 'Boxplot_Tension_Total.pdf', 'ContentType', 'vector');
% Guardar Figura 10
exportgraphics(figure(10), 'Boxplot_Desplazamiento_Linea.pdf', 'ContentType', 'vector');
% Guardar Figura 11
exportgraphics(figure(11), 'Plot_Velocidad_Desplazamiento_Linea.pdf', 'ContentType', 'vector');
disp('¡Todas las gráficas han sido guardadas!');