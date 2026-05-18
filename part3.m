%% ========================================================================
%  lab1_build_simulink.m
%  Программное построение Simulink-модели по методике из Раздела 1
%  (Вариант 1) учебно-практического пособия.
%
%  Запуск:   >> lab1_build_simulink
%  Результат: создаётся и открывается модель  lab1_variant1.slx
%             рядом с этим скриптом, затем выполняется симуляция и
%             выводится график состояния буфера.
%
%  Структура модели:
%       [Clock]──[Round]──┬──► (для log2)
%                         └──► (для lambda)
%
%       lambda(t) = lambda0 + t                              (линейный)
%       mu(t)     = round( log2(t)/log2(2) + mu0 )           (логарифм.)
%
%       dB/dt = lambda - mu  →  [Integrator]
%                              →  [Switch  (B>=0)]
%                              →  [Switch  (B<=K)]
%                              →  [Scope]
% =========================================================================

clear; clc; close all;
bdclose all;

%% -------------------- 1. Параметры (как в lab1_simulation.m) ------------
N           = 17;
group_size  = 17;

rng(N);
r           = rand(1, group_size);
lambda0     = r(N);
mu0         = r(mod(N-2, group_size) + 1);

K           = N;        % максимальный объём буфера, бит
B0          = 0;        % начальное состояние буфера
T_sim       = 30;       % время моделирования, с
dt          = 1;        % шаг дискретного времени, с

% Параметры экспортируются в base workspace, чтобы блоки могли на них
% ссылаться по имени.
assignin('base','lambda0', lambda0);
assignin('base','mu0',     mu0);
assignin('base','K',       K);
assignin('base','B0',      B0);
assignin('base','dt',      dt);

%% -------------------- 2. Создание новой модели --------------------------
modelName = 'lab1_variant1';
new_system(modelName);
open_system(modelName);

set_param(modelName, ...
    'Solver',         'FixedStepDiscrete', ...
    'FixedStep',      'dt', ...
    'StartTime',      '0', ...
    'StopTime',       num2str(T_sim));

%% -------------------- 3. Вспомогательная функция размещения -------------
% Удобно задавать [x y] и получать прямоугольник [x y x+w y+h].
pos = @(x,y,w,h) [x y x+w y+h];

%% -------------------- 4. Блоки источника времени ------------------------
% «Дискретные часы» с шагом dt: дают целочисленное значение времени.
add_block('simulink/Sources/Digital Clock',   [modelName '/Clock'], ...
          'SampleTime','dt', ...
          'Position', pos(30, 30, 40, 30));

% Блок «Функция округления» сохранения целостности (на случай нецелого dt).
add_block('simulink/Math Operations/Rounding Function', ...
          [modelName '/Round_t'], ...
          'Operator','floor', ...
          'Position', pos(110, 30, 50, 30));

%% -------------------- 5. lambda(t) = lambda0 + t ------------------------
add_block('simulink/Sources/Constant',        [modelName '/lambda0'], ...
          'Value','lambda0', ...
          'Position', pos(110, 100, 50, 30));

add_block('simulink/Math Operations/Add',     [modelName '/Sum_lambda'], ...
          'Inputs','++', ...
          'Position', pos(220, 60, 30, 30));

%% -------------------- 6. mu(t) = round( log2(t) + mu0 ) -----------------
% Логарифм по основанию 2 реализуем по формуле приведения:
%     log2(t) = ln(t) / ln(2)
%
% Защита от log(0): при t = 0 (первый отсчёт) ln(0) = -Inf, что портит
% весь канал mu(t). Поэтому ставим Saturation с нижним пределом 1.
add_block('simulink/Discontinuities/Saturation', ...
          [modelName '/Sat_t'], ...
          'LowerLimit','1','UpperLimit','inf', ...
          'Position', pos(160, 180, 40, 30));

add_block('simulink/Math Operations/Math Function', ...
          [modelName '/Log_t'], 'Operator','log', ...
          'Position', pos(220, 180, 60, 30));

add_block('simulink/Sources/Constant',        [modelName '/two'], ...
          'Value','2', ...
          'Position', pos(110, 230, 50, 30));

add_block('simulink/Math Operations/Math Function', ...
          [modelName '/Log_2'], 'Operator','log', ...
          'Position', pos(220, 230, 60, 30));

% Divide:  '*/'  =  «первый вход умножить, на второй разделить»
%          даёт   Log_t / Log_2  =  log2(t).
add_block('simulink/Math Operations/Divide',  [modelName '/Divide'], ...
          'Inputs','*/', ...
          'Position', pos(320, 200, 30, 30));

add_block('simulink/Sources/Constant',        [modelName '/mu0'], ...
          'Value','mu0', ...
          'Position', pos(320, 270, 50, 30));

add_block('simulink/Math Operations/Add',     [modelName '/Sum_mu'], ...
          'Inputs','++', ...
          'Position', pos(400, 220, 30, 30));

add_block('simulink/Math Operations/Rounding Function', ...
          [modelName '/Round_mu'], 'Operator','round', ...
          'Position', pos(460, 220, 50, 30));

%% -------------------- 7. dB/dt = lambda - mu, интегратор ----------------
add_block('simulink/Math Operations/Add',     [modelName '/Diff'], ...
          'Inputs','+-', ...
          'Position', pos(560, 120, 30, 30));

% Дискретный интегратор соответствует решению ОДУ 1-го порядка по схеме
% Эйлера с шагом dt (методичка рекомендует dt = 1).
add_block('simulink/Discrete/Discrete-Time Integrator', ...
          [modelName '/Buffer'], ...
          'InitialCondition','B0', ...
          'SampleTime','dt', ...
          'Position', pos(620, 120, 40, 30));

%% -------------------- 8. Ограничение B >= 0 (Switch) --------------------
add_block('simulink/Sources/Constant',        [modelName '/zero'], ...
          'Value','0', ...
          'Position', pos(700, 60, 30, 30));

add_block('simulink/Signal Routing/Switch',   [modelName '/Sw_nonneg'], ...
          'Criteria','u2 >= Threshold', ...
          'Threshold','0', ...
          'Position', pos(740, 100, 40, 60));

%% -------------------- 9. Ограничение B <= K (Switch) --------------------
add_block('simulink/Sources/Constant',        [modelName '/Kmax'], ...
          'Value','K', ...
          'Position', pos(800, 50, 30, 30));

% Simulink-Switch поддерживает только критерии  u2>=Th, u2>Th, u2~=0.
% Логика «B <= K, иначе K» эквивалентна «B > K → K, иначе B»:
%   вход 1 (true)  = K     — при переполнении выдаём максимум
%   вход 2 (управл.) = B
%   вход 3 (false) = B     — иначе пропускаем буфер как есть
add_block('simulink/Signal Routing/Switch',   [modelName '/Sw_cap'], ...
          'Criteria','u2 > Threshold', ...
          'Threshold','K', ...
          'Position', pos(840, 100, 40, 60));

%% -------------------- 10. Вывод --------------------------------------------
add_block('simulink/Sinks/Scope',             [modelName '/Scope_Buffer'], ...
          'Position', pos(920, 110, 50, 40));

add_block('simulink/Sinks/To Workspace',      [modelName '/B_log'], ...
          'VariableName','B_log','SaveFormat','Timeseries', ...
          'Position', pos(920, 170, 60, 30));

%% -------------------- 11. Соединение блоков -----------------------------
add_line(modelName,'Clock/1','Round_t/1');

% lambda(t)
add_line(modelName,'Round_t/1','Sum_lambda/1', 'autorouting','on');
add_line(modelName,'lambda0/1','Sum_lambda/2', 'autorouting','on');

% mu(t) — Log_t/Log_2 + mu0   (через Sat_t, чтобы избежать ln(0))
add_line(modelName,'Round_t/1','Sat_t/1',     'autorouting','on');
add_line(modelName,'Sat_t/1',  'Log_t/1',     'autorouting','on');
add_line(modelName,'two/1',    'Log_2/1',     'autorouting','on');
add_line(modelName,'Log_t/1', 'Divide/1',     'autorouting','on');
add_line(modelName,'Log_2/1', 'Divide/2',     'autorouting','on');
add_line(modelName,'Divide/1', 'Sum_mu/1',     'autorouting','on');
add_line(modelName,'mu0/1',    'Sum_mu/2',     'autorouting','on');
add_line(modelName,'Sum_mu/1', 'Round_mu/1',   'autorouting','on');

% dB/dt = lambda - mu
add_line(modelName,'Sum_lambda/1','Diff/1',    'autorouting','on');
add_line(modelName,'Round_mu/1',  'Diff/2',    'autorouting','on');
add_line(modelName,'Diff/1',      'Buffer/1',    'autorouting','on');

% Ограничение B >= 0
add_line(modelName,'Buffer/1',  'Sw_nonneg/2',      'autorouting','on'); % control
add_line(modelName,'Buffer/1',  'Sw_nonneg/1',      'autorouting','on'); % data (B)
add_line(modelName,'zero/1',  'Sw_nonneg/3',      'autorouting','on'); % data (0)

% Ограничение B <= K  (логика инвертирована, см. выше)
add_line(modelName,'Sw_nonneg/1','Sw_cap/2',     'autorouting','on'); % control = B
add_line(modelName,'Kmax/1',     'Sw_cap/1',     'autorouting','on'); % true  : K
add_line(modelName,'Sw_nonneg/1','Sw_cap/3',     'autorouting','on'); % false : B

% Вывод
add_line(modelName,'Sw_cap/1','Scope_Buffer/1', 'autorouting','on');
add_line(modelName,'Sw_cap/1','B_log/1',       'autorouting','on');

%% -------------------- 12. Сохранение, симуляция, отображение ------------
[scriptDir,~,~] = fileparts(mfilename('fullpath'));
if isempty(scriptDir), scriptDir = pwd; end
slxPath = fullfile(scriptDir, [modelName '.slx']);
save_system(modelName, slxPath);
fprintf('Модель сохранена: %s\n', slxPath);

simOut = sim(modelName);
fprintf('Симуляция завершена. Откройте Scope «Scope_Buffer» в модели.\n');

% Дополнительно — построим итоговый график в figure.
try
    B_ts = simOut.B_log;
    figure('Name','Simulink: состояние буфера','Color','w');
    stairs(B_ts.Time, B_ts.Data, 'LineWidth', 1.8); grid on;
    yline(K,'--r',sprintf('K = %d',K));
    xlabel('t, c'); ylabel('Buffer, бит');
    title('Раздел 1, Вариант 1 — буфер приёмника (Simulink)');
catch ME
    warning('Не удалось построить итоговый график: %s', ME.message);
end
