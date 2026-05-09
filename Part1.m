%% ============================================================
%  PART 1: Standard Simulink ONLY (NO SimEvents required)
%  Continuous-Deterministic Approach (НДП)
%  Infinite Buffer — Preliminary Task 1
%
%  Group: 17  |  Student number: 17
%  Parameters:
%    lambda = 17 bits/s  (порядковый номер в группе)
%    mu     = 10 bits/s  (constant service rate per task)
%    Buffer = infinite   (неограниченный буфер)
%
%  Differential equation modelled:
%    dq/dt = lambda - mu
%    q(0)  = 0
%
%  FIX 1: simOut object used — no undefined 'tout' variable
%  FIX 2: Integrator lower saturation set to 0 (buffer >= 0 always)
% ============================================================

clear; clc; close all;

%% ── PARAMETERS ──────────────────────────────────────────────
lambda = 17;       % Input  rate [bits/s]  — порядковый номер
mu     = 10;       % Service rate [bits/s] — задано условием
T_sim  = 10;       % Simulation duration [s]

fprintf('==============================================\n');
fprintf('  PART 1 — Standard Simulink (НДП) Model\n');
fprintf('==============================================\n');
fprintf('Student number  : 17\n');
fprintf('lambda (input)  : %d bits/s\n', lambda);
fprintf('mu (service)    : %d bits/s\n', mu);
fprintf('Net rate dq/dt  : %d - %d = %+d bits/s\n', lambda, mu, lambda-mu);
fprintf('Expected q(%ds) : %d bits\n', T_sim, (lambda-mu)*T_sim);
fprintf('----------------------------------------------\n\n');

%% ── CREATE / RESET MODEL ────────────────────────────────────
modelName = 'Part1_NDP_InfiniteBuffer';

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
if exist([modelName '.slx'], 'file')
    delete([modelName '.slx']);
end

new_system(modelName);
open_system(modelName);

%% ── SOLVER SETTINGS ─────────────────────────────────────────
set_param(modelName, 'StopTime',  num2str(T_sim));
set_param(modelName, 'Solver',    'ode45');
set_param(modelName, 'MaxStep',   '0.01');
set_param(modelName, 'SaveTime',  'on');          % FIX 1 — guarantees tout
set_param(modelName, 'TimeSaveName', 'tout');

%% ── BLOCK POSITIONS ─────────────────────────────────────────
% Layout (left → right):
%  Lambda(Const)  ──┐
%                   ├→ Sum(dq_dt) → Integrator(Buffer) → Scope / ToWS
%  Mu(Const)     ──┘
%  Clock → Gain_Theory → Scope (port 2 — theoretical line)

pos_lambda  = [50,  90,  90, 120];
pos_mu      = [50, 160,  90, 190];
pos_sum     = [160, 115, 190, 175];
pos_integ   = [260, 110, 310, 180];
pos_scope   = [430,  70, 510, 200];
pos_clock   = [260, 250, 300, 280];
pos_gain    = [360, 240, 410, 290];
pos_display = [430, 250, 490, 280];
pos_tows    = [430, 310, 470, 340];

%% ── ADD BLOCKS ───────────────────────────────────────────────

% 1. Constant: lambda
add_block('simulink/Sources/Constant', [modelName '/Lambda']);
set_param([modelName '/Lambda'], 'Value',    num2str(lambda));
set_param([modelName '/Lambda'], 'Position', pos_lambda);

% 2. Constant: mu
add_block('simulink/Sources/Constant', [modelName '/Mu']);
set_param([modelName '/Mu'], 'Value',    num2str(mu));
set_param([modelName '/Mu'], 'Position', pos_mu);

% 3. Sum: dq/dt = lambda - mu  (inputs: +-)
add_block('simulink/Math Operations/Sum', [modelName '/dq_dt']);
set_param([modelName '/dq_dt'], 'Inputs',   '+-');
set_param([modelName '/dq_dt'], 'Position', pos_sum);

% 4. Integrator: q(t) = integral(dq/dt), q(0) = 0
%    FIX 2 — LowerSaturationLimit = 0 (buffer cannot be negative)
add_block('simulink/Continuous/Integrator', [modelName '/Buffer']);
set_param([modelName '/Buffer'], 'InitialCondition',     '0');
set_param([modelName '/Buffer'], 'LimitOutput',          'on');
set_param([modelName '/Buffer'], 'LowerSaturationLimit', '0');
set_param([modelName '/Buffer'], 'UpperSaturationLimit', 'inf');
set_param([modelName '/Buffer'], 'Position', pos_integ);

% 5. Scope — 2 ports: simulated q(t) | theoretical line
add_block('simulink/Sinks/Scope', [modelName '/Scope_Queue']);
set_param([modelName '/Scope_Queue'], 'NumInputPorts', '2');
set_param([modelName '/Scope_Queue'], 'Position', pos_scope);

% 6. Clock — provides time signal t
add_block('simulink/Sources/Clock', [modelName '/Clock']);
set_param([modelName '/Clock'], 'Position', pos_clock);

% 7. Gain — theoretical slope = lambda - mu
add_block('simulink/Math Operations/Gain', [modelName '/Gain_Theory']);
set_param([modelName '/Gain_Theory'], 'Gain',     num2str(lambda - mu));
set_param([modelName '/Gain_Theory'], 'Position', pos_gain);

% 8. Display — shows final buffer value
add_block('simulink/Sinks/Display', [modelName '/Display_Q']);
set_param([modelName '/Display_Q'], 'Position', pos_display);

% 9. To Workspace — exports buffer data for post-processing plot
add_block('simulink/Sinks/To Workspace', [modelName '/ToWS_Buffer']);
set_param([modelName '/ToWS_Buffer'], 'VariableName', 'buffer_data');
set_param([modelName '/ToWS_Buffer'], 'SaveFormat',   'Array');
set_param([modelName '/ToWS_Buffer'], 'Position', pos_tows);

%% ── CONNECT BLOCKS ───────────────────────────────────────────
add_line(modelName, 'Lambda/1',      'dq_dt/1');          % λ  → Sum (+)
add_line(modelName, 'Mu/1',          'dq_dt/2');          % μ  → Sum (-)
add_line(modelName, 'dq_dt/1',       'Buffer/1');         % dq/dt → Integrator
add_line(modelName, 'Buffer/1',      'Scope_Queue/1');    % q(t)  → Scope port 1
add_line(modelName, 'Buffer/1',      'Display_Q/1');      % q(t)  → Display
add_line(modelName, 'Buffer/1',      'ToWS_Buffer/1');    % q(t)  → Workspace
add_line(modelName, 'Clock/1',       'Gain_Theory/1');    % t     → Gain
add_line(modelName, 'Gain_Theory/1', 'Scope_Queue/2');    % theory→ Scope port 2

%% ── ANNOTATION ───────────────────────────────────────────────
anno_str = sprintf([...
    'НДП — Раздел 1 | Предварительное задание 1\n', ...
    'Differential equation:  dq/dt = lambda - mu\n', ...
    'lambda = %d bits/s,  mu = %d bits/s\n', ...
    'Net rate = %+d bits/s  =>  q(t) = %d * t\n', ...
    'Buffer: INFINITE (no upper limit)\n', ...
    'At t = %d s:  q = %d bits'], ...
    lambda, mu, lambda-mu, lambda-mu, T_sim, (lambda-mu)*T_sim);

anno = Simulink.Annotation(modelName, anno_str);
anno.Position    = [50, 400];
anno.FontSize    = 10;
anno.BackgroundColor = '[0.85 1.0 0.85]';

%% ── SAVE & RUN ───────────────────────────────────────────────
save_system(modelName);
fprintf('Model saved: %s.slx\n\n', modelName);

fprintf('>>> Running simulation ...\n');
simOut = sim(modelName);           % FIX 1 — use simOut object
fprintf('    Simulation complete.\n\n');

%% ── EXTRACT RESULTS ──────────────────────────────────────────
% FIX 1: pull time and data from the simOut object — never rely on bare 'tout'
t_sim   = simOut.tout;
q_sim   = simOut.get('buffer_data');

% Theoretical solution: q_theory(t) = (lambda - mu) * t
q_theory = (lambda - mu) * t_sim;

%% ── OPEN SCOPE ───────────────────────────────────────────────
open_system([modelName '/Scope_Queue']);
fprintf('>>> Scope opened (use binoculars / autoscale to fit).\n\n');

%% ── MATLAB FIGURE ────────────────────────────────────────────
fig = figure('Name', 'Part 1 — Buffer State q(t)', ...
             'NumberTitle', 'off', ...
             'Position', [100 100 860 540]);

% ── Main plot
subplot(2,1,1);
plot(t_sim, q_sim,    'b-',  'LineWidth', 2.2, 'DisplayName', 'Simulated  q(t)');
hold on;
plot(t_sim, q_theory, 'r--', 'LineWidth', 1.6, 'DisplayName', ...
     sprintf('Theoretical: q(t) = %d·t', lambda-mu));
xlabel('Time  t  [s]',            'FontSize', 12);
ylabel('Buffer occupancy  [bits]', 'FontSize', 12);
title(sprintf('Part 1 — Infinite Buffer  (\\lambda = %d,  \\mu = %d,  dq/dt = %+d)', ...
      lambda, mu, lambda-mu), 'FontSize', 13);
legend('Location', 'northwest', 'FontSize', 11);
grid on;
annotation('textbox', [0.14, 0.72, 0.28, 0.14], ...
    'String', sprintf('Slope = %d bits/s\nAt t = %ds:  q = %d bits', ...
                      lambda-mu, T_sim, (lambda-mu)*T_sim), ...
    'FitBoxToText', 'on', 'BackgroundColor', [1 1 0.7], ...
    'FontSize', 11, 'EdgeColor', [0.6 0.6 0]);

% ── Rate comparison bar (bottom subplot)
subplot(2,1,2);
bar([lambda, mu, lambda-mu], 'FaceColor', 'flat', ...
    'CData', [0 0.45 0.74; 0.85 0.33 0.1; 0.47 0.67 0.19]);
set(gca, 'XTickLabel', {'\lambda (input)', '\mu (service)', 'Net \Deltaq/\Deltat'});
ylabel('bits / s', 'FontSize', 12);
title('Rate comparison', 'FontSize', 12);
grid on; ylim([0, max(lambda, mu)*1.3]);
yline(0, 'k-', 'LineWidth', 1);

saveas(fig, '/home/claude/part1_buffer_plot.png');
fprintf('Figure saved: part1_buffer_plot.png\n\n');

%% ── CONSOLE REPORT ───────────────────────────────────────────
fprintf('==============================================\n');
fprintf('  RESULTS SUMMARY\n');
fprintf('==============================================\n');
fprintf('Blocks in model:\n');
fprintf('  1. Constant  "Lambda"      — value %d bits/s\n', lambda);
fprintf('  2. Constant  "Mu"          — value %d bits/s\n', mu);
fprintf('  3. Sum       "dq_dt"       — inputs: +-\n');
fprintf('  4. Integrator"Buffer"      — q(0)=0, lower sat=0, upper=inf\n');
fprintf('  5. Scope     "Scope_Queue" — 2 ports\n');
fprintf('  6. Clock     "Clock"       — time source\n');
fprintf('  7. Gain      "Gain_Theory" — slope %d\n', lambda-mu);
fprintf('  8. Display   "Display_Q"   — live readout\n');
fprintf('  9. ToWorkspace"ToWS_Buffer"— exports buffer_data\n');
fprintf('----------------------------------------------\n');
fprintf('Differential equation:  dq/dt = %d - %d = %+d\n', lambda, mu, lambda-mu);
fprintf('Analytical solution:    q(t)  = %d · t\n', lambda-mu);
fprintf('At t = %d s:            q     = %d bits\n', T_sim, (lambda-mu)*T_sim);
fprintf('\nStatus: lambda > mu => queue GROWS without bound\n');
fprintf('==============================================\n');