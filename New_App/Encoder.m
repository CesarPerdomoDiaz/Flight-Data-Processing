fontTitle  = 30;
fontLabels = 25;
fontLegend = 20;
fontTicks  = 15;

%% Kitesurf
Encoder_H_kite2 = log_kite2_1{30000:end, 40};
Encoder_V_kite2 = log_kite2_1{30000:end, 41};

figure;
plot(Encoder_H_kite2, Encoder_V_kite2, 'LineWidth', 1.2);
grid on;

title('Posici\''on vertical vs posici\''on horizontal (Kitesurf)', ...
      'Interpreter', 'latex', 'FontSize', fontTitle);

xlabel('Posici\''on horizontal (Encoder H)', ...
       'Interpreter', 'latex', 'FontSize', fontLabels);

ylabel('Posici\''on vertical (Encoder V)', ...
       'Interpreter', 'latex', 'FontSize', fontLabels);

legend({'Single Skin'}, 'Interpreter','latex', ...
       'FontSize', fontLegend, 'Location','best');

set(gca, 'FontSize', fontTicks, 'TickLabelInterpreter', 'latex');

%% Single Skin
Encoder_H_single = log_single_1{13000:end, 40};
Encoder_V_single = log_single_1{13000:end, 41};

figure;
plot(Encoder_H_single, Encoder_V_single, 'LineWidth', 1.2);
grid on;

title('Posici\''on vertical vs posici\''on horizontal (Single Skin)', ...
      'Interpreter', 'latex', 'FontSize', fontTitle);

xlabel('Posici\''on horizontal (Encoder H)', ...
       'Interpreter', 'latex', 'FontSize', fontLabels);

ylabel('Posici\''on vertical (Encoder V)', ...
       'Interpreter', 'latex', 'FontSize', fontLabels);

legend({'Single Skin'}, 'Interpreter','latex', ...
       'FontSize', fontLegend, 'Location','best');

set(gca, 'FontSize', fontTicks, 'TickLabelInterpreter', 'latex');
