%% ============================================================
%  PART 2: Discrete-Event FIFO Queue with Timeout
%  Logic ported from Julia reference implementation
%  Implemented in MATLAB / Simulink (R2024b)
%
%  Group: 17  |  Student number: 17
%  lambda  = 17 bits/s   (arrival rate)
%  mu      = 10 bits/s   (service rate)
%  t_lim   = 17/10^2 = 0.17 s  (max wait time per bit)
%
%  Queue logic (same as Julia):
%    STEP 1 — Arrivals:  bits arrive at t = n/lambda, pushed to buffer
%    STEP 2 — Service:   server takes bits FIFO when free (rate=mu)
%    STEP 3 — Timeout:   drop oldest bit if it waited > t_lim
%
%  Two separate output figures:
%    1) q(t)      — number of bits currently in buffer
%    2) n_drop(t) — cumulative bits dropped by timeout
%% ============================================================

clear; clc; close all;

%% ── PARAMETERS ──────────────────────────────────────────────
lambda = 17;            % bits/s  — arrival rate
mu     = 10;            % bits/s  — service rate
t_lim  = 17 / 10^2;    % = 0.17 s — timeout per bit
T_sim  = 15;            % simulation time [s]

fprintf('==============================================\n');
fprintf('  PART 2 — Discrete-Event Timeout Model\n');
fprintf('  (Simulink + MATLAB Function block)\n');
fprintf('==============================================\n');
fprintf('MATLAB version : R2024b\n');
fprintf('lambda         : %d bits/s\n',   lambda);
fprintf('mu             : %d bits/s\n',   mu);
fprintf('t_lim          : %.4f s\n',      t_lim);
fprintf('Sim duration   : %d s\n',        T_sim);
fprintf('Expected stable queue : %.2f bits  (lambda*t_lim)\n', lambda*t_lim);
fprintf('Expected drop rate    : %d bits/s  (lambda-mu)\n',    lambda-mu);
fprintf('----------------------------------------------\n\n');

%% ── CREATE / RESET MODEL ─────────────────────────────────────
modelName = 'Part2_DiscreteEvent';

if bdIsLoaded(modelName),           close_system(modelName, 0); end
if exist([modelName '.slx'], 'file'), delete([modelName '.slx']); end

new_system(modelName);
open_system(modelName);

%% ── SOLVER ───────────────────────────────────────────────────
%  ode1 = Fixed-step Euler: evaluates outputs ONCE per step in
%  monotonically increasing order — required for persistent
%  variable logic inside the MATLAB Function block.
set_param(modelName, 'SolverType',             'Fixed-step');
set_param(modelName, 'Solver',                 'ode1');
set_param(modelName, 'FixedStep',              '0.001');
set_param(modelName, 'StopTime',               num2str(T_sim));
set_param(modelName, 'SaveTime',               'on');
set_param(modelName, 'TimeSaveName',           'tout');
set_param(modelName, 'ReturnWorkspaceOutputs', 'on');

%% ── BLOCK POSITIONS ──────────────────────────────────────────
%
%  Layout:
%
%  Clock  →  QueueLogic (MATLAB Function)  →  port 1: q      → Scope_Q / ToWS_Q
%                                           →  port 2: n_drop → Scope_D / ToWS_D

pos_clock      = [50,  130, 90,  170];
pos_queuelogic = [170, 95,  380, 205];
pos_scope_q    = [480, 85,  540, 135];
pos_tows_q     = [480, 150, 560, 180];
pos_scope_d    = [480, 220, 540, 270];
pos_tows_d     = [480, 285, 560, 315];

%% ── ADD BLOCKS ───────────────────────────────────────────────

% 1. Clock — provides simulation time t to the function block
add_block('simulink/Sources/Clock', [modelName '/Clock']);
set_param([modelName '/Clock'], 'Position', pos_clock);

% 2. MATLAB Function — discrete-event queue (same logic as Julia)
add_block('simulink/User-Defined Functions/MATLAB Function', ...
          [modelName '/QueueLogic']);
set_param([modelName '/QueueLogic'], 'Position', pos_queuelogic);

% 3. Scope — buffer state q(t)
add_block('simulink/Sinks/Scope', [modelName '/Scope_Q']);
set_param([modelName '/Scope_Q'], 'NumInputPorts', '1', ...
          'Position', pos_scope_q);

% 4. To Workspace — saves q(t)
add_block('simulink/Sinks/To Workspace', [modelName '/ToWS_Q']);
set_param([modelName '/ToWS_Q'], ...
    'VariableName', 'q_out', ...
    'SaveFormat',   'Array', ...
    'Position',     pos_tows_q);

% 5. Scope — cumulative dropped bits
add_block('simulink/Sinks/Scope', [modelName '/Scope_D']);
set_param([modelName '/Scope_D'], 'NumInputPorts', '1', ...
          'Position', pos_scope_d);

% 6. To Workspace — saves n_drop(t)
add_block('simulink/Sinks/To Workspace', [modelName '/ToWS_D']);
set_param([modelName '/ToWS_D'], ...
    'VariableName', 'd_out', ...
    'SaveFormat',   'Array', ...
    'Position',     pos_tows_d);

%% ── MATLAB FUNCTION BLOCK SCRIPT ────────────────────────────
%
%  Three-step logic identical to the Julia reference:
%
%  STEP 1 — Arrivals
%    Bit n arrives at t = n/lambda. All bits whose arrival time
%    <= current t are pushed into the buffer with their timestamp.
%
%  STEP 2 — Service
%    While the server is free (server_busy_until <= t) and the
%    buffer is non-empty, take the oldest bit and serve it.
%    Server becomes busy for 1/mu seconds.
%
%  STEP 3 — Timeout
%    While the oldest bit in the buffer has waited > t_lim,
%    discard it and increment the drop counter.
%
%  Persistent variables survive across time steps (like Julia globals).
%  Buffer is pre-allocated to MAX_BUF to avoid dynamic resizing.

func_code = sprintf([...
    'function [q_out, n_drop_out] = queue_step(t)\n', ...
    '%% Discrete-event FIFO queue with timeout\n', ...
    '%% Ported from Julia: arrivals -> service -> timeout\n', ...
    '%% lambda=%.1f  mu=%.1f  t_lim=%.4f\n', ...
    '\n', ...
    '    persistent n_arr n_drop buffer buf_size server_busy_until\n', ...
    '\n', ...
    '    LAMBDA  = %.1f;     %% bits/s arrival rate\n', ...
    '    MU      = %.1f;     %% bits/s service rate\n', ...
    '    T_LIM   = %.4f;  %% seconds timeout\n', ...
    '    MAX_BUF = 2000;    %% pre-allocated buffer size\n', ...
    '\n', ...
    '    if isempty(n_arr)\n', ...
    '        n_arr             = 0.0;\n', ...
    '        n_drop            = 0.0;\n', ...
    '        buffer            = zeros(1, MAX_BUF);\n', ...
    '        buf_size          = 0.0;\n', ...
    '        server_busy_until = 0.0;\n', ...
    '    end\n', ...
    '\n', ...
    '    %% STEP 1 - Arrivals\n', ...
    '    %% Bit n_arr arrives at t = n_arr/LAMBDA (uniform stream)\n', ...
    '    %% Add all bits that have arrived by current time t\n', ...
    '    while n_arr / LAMBDA <= t\n', ...
    '        buf_size          = buf_size + 1;\n', ...
    '        buffer(buf_size)  = n_arr / LAMBDA;  %% store arrival time\n', ...
    '        n_arr             = n_arr + 1;\n', ...
    '    end\n', ...
    '\n', ...
    '    %% STEP 2 - Server processing\n', ...
    '    %% While server is free, serve the oldest bit (FIFO)\n', ...
    '    while buf_size > 0 && server_busy_until <= t\n', ...
    '        start_time        = max(t, buffer(1));\n', ...
    '        server_busy_until = start_time + 1.0 / MU;\n', ...
    '        if buf_size > 1\n', ...
    '            buffer(1:buf_size-1) = buffer(2:buf_size);\n', ...
    '        end\n', ...
    '        buf_size = buf_size - 1;\n', ...
    '    end\n', ...
    '\n', ...
    '    %% STEP 3 - Timeout check\n', ...
    '    %% Drop oldest bit if it has waited longer than T_LIM\n', ...
    '    while buf_size > 0 && (t - buffer(1)) > T_LIM\n', ...
    '        if buf_size > 1\n', ...
    '            buffer(1:buf_size-1) = buffer(2:buf_size);\n', ...
    '        end\n', ...
    '        buf_size = buf_size - 1;\n', ...
    '        n_drop   = n_drop + 1;\n', ...
    '    end\n', ...
    '\n', ...
    '    q_out      = buf_size;   %% current buffer length\n', ...
    '    n_drop_out = n_drop;     %% cumulative dropped bits\n', ...
    'end\n'], ...
    lambda, mu, t_lim, lambda, mu, t_lim);

% Inject the script via Stateflow API (handles MATLAB Function blocks)
rt    = sfroot;
model = rt.find('-isa', 'Simulink.BlockDiagram', 'Name', modelName);
chart = model.find('-isa', 'Stateflow.EMChart', '-depth', inf);
if isempty(chart)
    error('Could not find MATLAB Function block. Check model creation step.');
end
chart.Script = func_code;

fprintf('MATLAB Function block script set.\n');

%% ── CONNECT BLOCKS ───────────────────────────────────────────
add_line(modelName, 'Clock/1',       'QueueLogic/1');  % t      → queue logic
add_line(modelName, 'QueueLogic/1',  'Scope_Q/1');     % q(t)   → scope
add_line(modelName, 'QueueLogic/1',  'ToWS_Q/1');      % q(t)   → workspace
add_line(modelName, 'QueueLogic/2',  'Scope_D/1');     % n_drop → scope
add_line(modelName, 'QueueLogic/2',  'ToWS_D/1');      % n_drop → workspace

%% ── ANNOTATION ───────────────────────────────────────────────
anno_str = sprintf([...
    'Part 2 — Discrete-Event Timeout Model (R2024b)\n', ...
    'Step 1: Arrivals  — bit n arrives at t = n/lambda\n', ...
    'Step 2: Service   — FIFO, server rate = mu\n', ...
    'Step 3: Timeout   — drop if wait > t_lim\n', ...
    'lambda=%d  mu=%d  t_lim=%.2f s\n', ...
    'Expected q_stable = lambda*t_lim = %.2f bits\n', ...
    'Expected drop rate = lambda-mu = %d bits/s'], ...
    lambda, mu, t_lim, lambda*t_lim, lambda-mu);

anno          = Simulink.Annotation(modelName, anno_str);
anno.Position = [50, 400];
anno.FontSize = 10;
anno.BackgroundColor = '[1 0.95 0.8]';

%% ── SAVE & RUN ───────────────────────────────────────────────
save_system(modelName);
fprintf('Model saved: %s.slx\n\n', modelName);

fprintf('>>> Running simulation...\n');
simOut = sim(modelName, 'ReturnWorkspaceOutputs', 'on');
fprintf('    Done.\n\n');

%% ── EXTRACT RESULTS ──────────────────────────────────────────
t_vec = simOut.tout;
q_vec = simOut.get('q_out');
d_vec = simOut.get('d_out');

% Align lengths (just in case)
n     = min([length(t_vec), length(q_vec), length(d_vec)]);
t_vec = t_vec(1:n);
q_vec = q_vec(1:n);
d_vec = d_vec(1:n);

%% ── OPEN SCOPES ──────────────────────────────────────────────
open_system([modelName '/Scope_Q']);
open_system([modelName '/Scope_D']);

%% ── SEPARATE MATLAB FIGURES (INSTEAD OF ONE COMBINED) ────────

% --- Figure 1: Buffer state q(t) ----------------------------
fig1 = figure('Name', 'Part 2 — Buffer State q(t)', ...
              'NumberTitle', 'off', ...
              'Position', [100, 100, 800, 450]);
stairs(t_vec, q_vec, 'b-', 'LineWidth', 1.8);
hold on;
yline(lambda * t_lim, 'b--', 'LineWidth', 1.5, ...
      'Label', sprintf('q_{stable} = %.2f bits', lambda*t_lim), ...
      'LabelHorizontalAlignment', 'left');
xlabel('Time  t  [s]', 'FontSize', 12);
ylabel('Buffer length  [bits]', 'FontSize', 12);
title(sprintf('Buffer state q(t)  (\\lambda=%d, \\mu=%d, t_{lim}=%.2f s)', ...
      lambda, mu, t_lim), 'FontSize', 13);
legend('q(t)', 'Theoretical stable level', 'Location', 'best');
grid on;
ylim([0, max(q_vec)*1.6 + 1]);

% Stats annotation
annotation('textbox', [0.60, 0.75, 0.35, 0.15], ...
    'String', sprintf('Final queue at t=%d s: %.0f bits', T_sim, q_vec(end)), ...
    'FitBoxToText', 'on', ...
    'BackgroundColor', [1 0.97 0.8], ...
    'FontSize', 11, 'EdgeColor', [0.7 0.5 0]);
saveas(fig1, 'part2_queue.png');

% --- Figure 2: Cumulative dropped bits n_drop(t) -------------
fig2 = figure('Name', 'Part 2 — Cumulative Dropped Bits', ...
              'NumberTitle', 'off', ...
              'Position', [100, 100, 800, 450]);
stairs(t_vec, d_vec, 'r-', 'LineWidth', 1.8);
hold on;
% Theoretical slope line (after initial transient)
t_stable   = t_lim * 5;   % approximate start of linear region
slope_line = max(0, (lambda - mu) * (t_vec - t_stable));
plot(t_vec, slope_line, 'k--', 'LineWidth', 1.5, ...
     'DisplayName', sprintf('Theoretical slope = %d bits/s', lambda-mu));
xlabel('Time  t  [s]', 'FontSize', 12);
ylabel('Cumulative dropped bits', 'FontSize', 12);
title(sprintf('Cumulative dropped bits n_{drop}(t)  (\\lambda=%d, \\mu=%d, t_{lim}=%.2f s)', ...
      lambda, mu, t_lim), 'FontSize', 13);
legend('n_{drop}(t)', sprintf('Expected rate %d bits/s', lambda-mu), 'Location', 'northwest');
grid on;

% Stats annotation
final_drop = d_vec(end);
drop_rate  = final_drop / T_sim;
annotation('textbox', [0.60, 0.20, 0.35, 0.15], ...
    'String', sprintf(['At t=%d s:\n' ...
                       'Total dropped = %.0f bits\n' ...
                       'Avg drop rate = %.2f bits/s'], ...
                       T_sim, final_drop, drop_rate), ...
    'FitBoxToText', 'on', ...
    'BackgroundColor', [1 0.97 0.8], ...
    'FontSize', 11, 'EdgeColor', [0.7 0.5 0]);
saveas(fig2, 'part2_drops.png');

%% ── CONSOLE REPORT ───────────────────────────────────────────
fprintf('==============================================\n');
fprintf('  PART 2 — RESULTS SUMMARY\n');
fprintf('==============================================\n');
fprintf('Final queue length    : %.0f bits\n',   q_vec(end));
fprintf('Total bits dropped    : %.0f bits\n',   final_drop);
fprintf('Avg drop rate         : %.4f bits/s\n', drop_rate);
fprintf('----------------------------------------------\n');
fprintf('Theory predictions:\n');
fprintf('  Stable queue  = lambda * t_lim = %d * %.2f = %.2f bits\n', ...
        lambda, t_lim, lambda*t_lim);
fprintf('  Stable drops  = lambda - mu    = %d - %d = %d bits/s\n', ...
        lambda, mu, lambda-mu);
fprintf('==============================================\n');
fprintf('\nBlocks used in model:\n');
fprintf('  1. Clock        Clock            provides t to function\n');
fprintf('  2. QueueLogic   MATLAB Function  3-step discrete-event logic:\n');
fprintf('       Step 1: Arrivals   — push bits (t=n/lambda) into buffer\n');
fprintf('       Step 2: Service    — FIFO dequeue at rate mu\n');
fprintf('       Step 3: Timeout    — drop bits waited > t_lim\n');
fprintf('       Output 1: q(t)     — current buffer size\n');
fprintf('       Output 2: n_drop   — cumulative dropped bits\n');
fprintf('  3. Scope_Q      Scope            live graph of q(t)\n');
fprintf('  4. Scope_D      Scope            live graph of n_drop(t)\n');
fprintf('  5. ToWS_Q       To Workspace     saves q(t)\n');
fprintf('  6. ToWS_D       To Workspace     saves n_drop(t)\n');
fprintf('==============================================\n');