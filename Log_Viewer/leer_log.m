function data = leer_log(filename)
    % LEER_LOG  Lee archivo CSV sin cabecera y asigna nombres de variables.
    % Añade también los campos calibrados:
    %   LC_left, LC_center, LC_right  (a partir de ADC_LC_1/2/3)
    %
    %   data = leer_log('logXX.csv');

    if nargin < 1
        filename = 'log05_kite.csv';
    end

    % Lista de nombres (los que me diste)
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

    % Leer archivo como matriz
    raw = readmatrix(filename);
    nCols = size(raw, 2);

    % Ajustar lista de nombres al número real de columnas
    if nCols > numel(varNames)
        for i = numel(varNames)+1:nCols
            varNames{end+1} = sprintf('extra_col_%d', i);
        end
    elseif nCols < numel(varNames)
        varNames = varNames(1:nCols);
    end

    % Crear struct con los valores crudos
    for i = 1:nCols
        data.(varNames{i}) = raw(:,i);
    end

    % =================== CALIBRACIÓN DE CELDAS DE CARGA ===================
    % Factores de calibración solicitados
    fc_LC_left   = 1.07;
    fc_LC_center = 1.04;
    fc_LC_right  = 1.08;
    data.LC_left   = double(data.ADC_LC_1) ./ 4096 * 100 * fc_LC_left   * 9.81;
    data.LC_center = double(data.ADC_LC_2) ./ 4096 * 200 * fc_LC_center * 9.81;
    data.LC_right  = double(data.ADC_LC_3) ./ 4096 * 100 * fc_LC_right  * 9.81;

    % =====================================================================
end
