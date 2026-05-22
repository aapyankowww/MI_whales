function plot_mi_standard(segment, fft_result, mi_result, output_path, ci_level)
%PLOT_MI_STANDARD Стандартизированное построение графика профиля MI.

if nargin < 5 || isempty(ci_level)
    ci_level = 0.95;
end

profile_samples = aggregate_profiles(mi_result.mi_values);
profile_stats = compute_profile_ci(profile_samples, ci_level);
perm_stats = [];

if isfield(mi_result, 'shift_mi') && ~isempty(mi_result.shift_mi)
    perm_samples = aggregate_shift(mi_result.shift_mi);
    perm_stats = compute_profile_ci(perm_samples, ci_level);
elseif isfield(mi_result, 'shift_stats') && ~isempty(mi_result.shift_stats)
    perm_stats = aggregate_shift_stats(mi_result.shift_stats, ci_level);
end

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 900]);
t = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(t, 1);
plot(ax1, fft_result.waveform_time_sec, fft_result.waveform, 'Color', [0.2 0.2 0.2], 'LineWidth', 0.7);
grid(ax1, 'on');
xlabel(ax1, 'Время, с');
ylabel(ax1, 'Амплитуда');
title(ax1, sprintf('Сегмент %s', segment.id), 'Interpreter', 'none');

ax2 = nexttile(t, 2);
hold(ax2, 'on');
fill_between(ax2, mi_result.dt_sec, profile_stats.ci_lower, profile_stats.ci_upper, [0.82 0.89 0.98]);
plot(ax2, mi_result.dt_sec, profile_stats.mean_profile, 'Color', [0.13 0.39 0.77], 'LineWidth', 2);
grid(ax2, 'on');
xlabel(ax2, 'Задержка, с');
ylabel(ax2, 'MI, нат');
title(ax2, build_profile_title(mi_result), 'Interpreter', 'none');
legend(ax2, {sprintf('%.0f%% доверительный интервал', ci_level * 100), 'Средний профиль MI'}, 'Location', 'best');

ax3 = nexttile(t, 3);
hold(ax3, 'on');
fill_between(ax3, mi_result.dt_sec, profile_stats.ci_lower, profile_stats.ci_upper, [0.82 0.89 0.98]);
plot(ax3, mi_result.dt_sec, profile_stats.mean_profile, 'Color', [0.13 0.39 0.77], 'LineWidth', 2);
if ~isempty(perm_stats)
    fill_between(ax3, mi_result.dt_sec, perm_stats.ci_lower, perm_stats.ci_upper, [0.95 0.86 0.80]);
    plot(ax3, mi_result.dt_sec, perm_stats.mean_profile, 'Color', [0.84 0.32 0.10], 'LineWidth', 1.8);
    legend(ax3, { ...
        sprintf('%.0f%% ДИ наблюдаемого MI', ci_level * 100), ...
        'Средний наблюдаемый MI', ...
        sprintf('%.0f%% ДИ permutation shift', ci_level * 100), ...
        'Средний permutation shift'}, 'Location', 'best');
else
    legend(ax3, { ...
        sprintf('%.0f%% ДИ наблюдаемого MI', ci_level * 100), ...
        'Средний наблюдаемый MI'}, 'Location', 'best');
end
grid(ax3, 'on');
xlabel(ax3, 'Задержка, с');
ylabel(ax3, 'MI, нат');
title(ax3, 'Сравнение с permutation shift', 'Interpreter', 'none');

sgtitle(t, sprintf('Профиль взаимной информации | bins=%d | perms=%d', ...
    mi_result.run_params.n_bins, mi_result.run_params.n_perms));

export_figure_standard(fig, output_path);
close(fig);
end

function profile_samples = aggregate_profiles(mi_values)
per_freq = squeeze(mean(mi_values, 3));
if isvector(per_freq)
    per_freq = per_freq(:).';
end
profile_samples = per_freq;
end

function perm_samples = aggregate_shift(shift_mi)
perm_by_delay = permute(shift_mi, [2, 1, 3, 4]);
n_delays = size(perm_by_delay, 1);
perm_samples = zeros(numel(perm_by_delay(1, :, :, :)), n_delays);

for di = 1:n_delays
    samples = perm_by_delay(di, :, :, :);
    samples = samples(:);
    perm_samples(:, di) = samples;
end
end

function perm_stats = aggregate_shift_stats(shift_stats, ci_level)
mean_samples = aggregate_profiles(shift_stats.mean);
mean_profile = mean(mean_samples, 1);

if isfield(shift_stats, 'std') && isfield(shift_stats, 'count') && shift_stats.count > 0
    std_samples = aggregate_profiles(shift_stats.std);
    std_profile = mean(std_samples, 1);
    z_value = -sqrt(2) * erfcinv(2 * (0.5 + ci_level / 2));
    sem_profile = max(std_profile, 0) ./ sqrt(shift_stats.count);
    ci_lower = mean_profile - z_value * sem_profile;
    ci_upper = mean_profile + z_value * sem_profile;
else
    ci_lower = mean_profile;
    ci_upper = mean_profile;
end

perm_stats = struct();
perm_stats.mean_profile = mean_profile;
perm_stats.ci_lower = ci_lower;
perm_stats.ci_upper = ci_upper;
end

function fill_between(ax, x, y1, y2, color_value)
fill(ax, [x(:); flipud(x(:))], [y1(:); flipud(y2(:))], color_value, ...
    'EdgeColor', 'none', 'FaceAlpha', 0.45);
end

function title_text = build_profile_title(mi_result)
if numel(mi_result.selected_freq_hz) == 1
    title_text = sprintf('Профиль MI для %.2f Гц', mi_result.selected_freq_hz);
else
    title_text = sprintf('Профиль MI для диапазона %.2f-%.2f Гц', ...
        mi_result.freq_band_hz(1), mi_result.freq_band_hz(2));
end
end
