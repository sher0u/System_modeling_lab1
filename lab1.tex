\documentclass[a4paper,12pt]{article}
\usepackage[utf8]{inputenc}
\usepackage[russian]{babel}
\usepackage{amsmath}
\usepackage{graphicx}
\usepackage{geometry}
\geometry{left=2cm, right=2cm, top=2cm, bottom=2cm}
\usepackage{caption}
\usepackage{hyperref}
\usepackage{setspace}
\usepackage{indentfirst}
\usepackage{titlesec}

% GOST-like formatting
\onehalfspacing          % 1.5 line spacing
\setlength{\parindent}{1.25cm} % paragraph indent
\titleformat{\section}[block]{\bfseries\large}{}{0pt}{}
\titleformat{\subsection}[block]{\bfseries\normalsize}{}{0pt}{}

\begin{document}

% Title
\begin{center}
    \textbf{\large Часть 1 -- Модель с постоянными интенсивностями}
\end{center}
\vspace{5mm}

\section*{Часть 1. Непрерывно-детерминированная модель с постоянными интенсивностями}

\subsection*{Цель}
Смоделировать передачу битового потока от источника к приёмнику с постоянными скоростями:
поступление $\lambda = 17$ бит/с, обработка $\mu = 10$ бит/с. Буфер неограничен, начальное
состояние $q(0)=0$.

\subsection*{Параметры модели}
Основные параметры модели сведены в таблицу~\ref{tab:params}.

\begin{table}[h!]
    \centering
    \caption{Параметры модели}
    \label{tab:params}
    \begin{tabular}{|l|c|l|}
        \hline
        Параметр & Обозначение & Значение \\
        \hline
        Интенсивность поступления & $\lambda$ & 17 бит/с \\
        Интенсивность обработки   & $\mu$    & 10 бит/с \\
        Максимальный размер буфера & $b$     & $\infty$ (не ограничен) \\
        Начальная очередь         & $q(0)$  & 0 бит \\
        Время моделирования       & $T$     & 10 с \\
        \hline
    \end{tabular}
\end{table}

\subsection*{Математическая модель}
Динамика очереди описывается дифференциальным уравнением первого порядка
\[
\frac{dq(t)}{dt} = \lambda - \mu = 7\ \text{бит/с}, \qquad q(0)=0,
\]
откуда аналитическое решение $q(t) = 7t$.

\subsection*{Реализация в Simulink}
Основные компоненты и их
настройки:
\begin{enumerate}
    \item \textbf{Constant (Lambda)} – значение $17$.
    \item \textbf{Constant (Mu)} – значение $10$.
    \item \textbf{Sum (dq\_dt)} – вычисляет разность $\lambda - \mu$ (входы $+-$).
    \item \textbf{Integrator (Buffer)} – интегрирует разность с начальным условием $0$.
          Включено ограничение выхода: нижний предел $0$ (очередь не может быть отрицательной),
          верхний предел $\infty$ (буфер неограничен).
    \item \textbf{Clock} и \textbf{Gain} (коэффициент $7$) – формируют теоретическую прямую
          $7t$ для сравнения с результатом моделирования.
    \item \textbf{Scope (Scope\_Queue)} – двухвходовой осциллограф; на первый вход подаётся
          $q(t)$, на второй – теоретическая прямая $7t$.
    \item \textbf{Display} и \textbf{To Workspace} – для наблюдения текущего значения
          и экспорта данных.
\end{enumerate}

\subsection*{Схема модели}
На рис.~\ref{fig:sheme_start} представлена блок-схема модели в начальный момент времени ($t = 0$).
На рис.~\ref{fig:sheme_end} – та же схема после завершения моделирования ($t = 10$ с),
когда в буфере накопилось 70 бит.

\begin{figure}[!ht]
    \centering
    \includegraphics[width=\textwidth]{scheme_start.png}   % <-- скриншот схемы при t = 0
    \caption{Схема модели в начальный момент времени ($t = 0$ с).}
    \label{fig:sheme_start}
\end{figure}

\begin{figure}[h!]
    \centering
    \includegraphics[width=\textwidth]{scheme_end.png}     % <-- скриншот схемы при t = 10 с
    \caption{Схема модели после 10 секунд моделирования ($t = 10$ с).}
    \label{fig:sheme_end}
\end{figure}

\subsection*{График состояния буфера}
На рис.~\ref{fig:graph} приведён график изменения длины очереди во времени, полученный с
помощью блока Scope.

\begin{figure}[h!]
    \centering
    \includegraphics[width=0.85\textwidth]{graph.png}      % <-- скриншот графика Scope
    \caption{График зависимости $q(t)$ от времени.}
    \label{fig:graph}
\end{figure}

\subsection*{Анализ}
Из уравнения $\frac{dq}{dt} = 7$ бит/с следует линейный рост очереди с наклоном $7$.
При $t = 10$ с теоретическое значение $q = 7 \times 10 = 70$ бит. Сравнение
рис.~\ref{fig:sheme_start} и \ref{fig:sheme_end} подтверждает, что за 10 секунд длина очереди
выросла от $0$ до $70$ бит, что полностью совпадает с аналитическим решением. Ограничение
интегратора снизу нулём гарантирует, что очередь никогда не принимает отрицательных значений.
Так как верхнее ограничение отключено, буфер ведёт себя как бесконечный – рост очереди не
прекращается.

\subsection*{Вывод по части 1}
При постоянных интенсивностях $\lambda > \mu$ и неограниченном буфере очередь неограниченно
возрастает по линейному закону $q(t) = (\lambda - \mu)\,t$. Результаты моделирования полностью
соответствуют аналитическому решению, что подтверждает корректность непрерывно-
детерминированного подхода для данной задачи.

\end{document}
