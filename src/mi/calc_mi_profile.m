function mi_result = calc_mi_profile(bin_matrix, fft_result, selected_freq_idx, selected_freq_hz, freq_band_hz, max_delay_sec, window_duration_sec, n_perms, binning_meta, segment)
%CALC_MI_PROFILE Канонический расчет профиля взаимной информации.
% Основан на исправленной логике mutual_info_quantile_shift.m.

[n_freqs, n_frames] = size(bin_matrix);
n_bins = binning_meta.n_bins;

frame_step_sec = infer_frame_step_sec(fft_result);
max_delay_frames = round(max_delay_sec / frame_step_sec);
window_dur_frames = round(window_duration_sec / frame_step_sec);

if max_delay_frames < 0
    error('max_delay_sec должен быть неотрицательным');
end
if window_dur_frames < 1
    error('window_duration_sec слишком мал для текущего шага FFT');
end

n_delays = 2 * max_delay_frames + 1;
n_windows = floor((n_frames - 2 * max_delay_frames) / window_dur_frames);
if n_windows < 1
    error(['Сегмент %s слишком короткий для выбранных параметров MI. ' ...
        'Требуется больше временных кадров FFT с запасом для лагов в обе стороны.'], segment.id);
end

hist_size = int32(n_bins * n_bins);
delay_offsets = int32(0:n_delays-1) .* hist_size;
delay_vec = int32(-max_delay_frames:max_delay_frames);

mi_values = zeros(n_freqs, n_delays, n_windows, 'single');
if n_perms > 0
    shift_mi = zeros(n_freqs, n_delays, n_perms, n_windows, 'single');
else
    shift_mi = [];
end

t0_frames = zeros(1, n_windows);

for wi = 1:n_windows
    start_col = max_delay_frames + (wi - 1) * window_dur_frames + 1;
    base_cols = int32(start_col : start_col + window_dur_frames - 1);
    t0_frames(wi) = start_col;

    shifted_cols = base_cols.' + delay_vec;

    if n_perms > 0
        base_shuffled_cols = shuffle_vector(base_cols, n_perms);
        shifted_shuffled_cols = shuffle_matrix_rows(shifted_cols, n_perms);
    end

    for fi = 1:n_freqs
        bin_row = bin_matrix(fi, :);
        mi_values(fi, :, wi) = mi_calc_core( ...
            base_cols, shifted_cols, window_dur_frames, n_delays, ...
            n_bins, delay_offsets, hist_size, bin_row);

        if n_perms > 0
            for pi = 1:n_perms
                shift_mi(fi, :, pi, wi) = mi_calc_core( ...
                    base_shuffled_cols(pi, :), ...
                    shifted_shuffled_cols(:, :, pi), ...
                    window_dur_frames, n_delays, n_bins, delay_offsets, ...
                    hist_size, bin_row);
            end
        end
    end
end

mi_result = struct();
mi_result.mi_values = mi_values;
mi_result.dt_frames = -max_delay_frames:max_delay_frames;
mi_result.dt_sec = (-max_delay_frames:max_delay_frames) * frame_step_sec;
mi_result.t0_frames = t0_frames;
mi_result.selected_freq_idx = selected_freq_idx;
mi_result.selected_freq_hz = selected_freq_hz;
mi_result.freq_band_hz = freq_band_hz;
mi_result.shift_stats = summarize_shift_tensor(shift_mi, 3);
mi_result.shift_mi = [];
mi_result.run_params = struct( ...
    'max_delay_sec', max_delay_sec, ...
    'max_delay_frames', max_delay_frames, ...
    'window_duration_sec', window_duration_sec, ...
    'window_duration_frames', window_dur_frames, ...
    'n_perms', n_perms, ...
    'frame_step_sec', frame_step_sec, ...
    'n_bins', n_bins, ...
    'lag_mode', 'symmetric');
mi_result.provenance = struct( ...
    'segment_id', segment.id, ...
    'binning_type', binning_meta.type, ...
    'source_algorithm', 'mutual_info_quantile_shift_based');
end

function frame_step_sec = infer_frame_step_sec(fft_result)
if numel(fft_result.time_sec) >= 2
    frame_step_sec = mean(diff(fft_result.time_sec));
else
    frame_step_sec = ...
        (fft_result.fft_params.window_samples - fft_result.fft_params.overlap_samples) ...
        / fft_result.sample_rate;
end

if ~isfinite(frame_step_sec) || frame_step_sec <= 0
    error('Не удалось определить шаг FFT по времени');
end
end

function shuffled_cols = shuffle_vector(cols, n_perms)
cols = int32(cols(:).');
n = numel(cols);
shuffled_cols = zeros(n_perms, n, 'int32');
random_values = rand(n_perms, n);
for pi = 1:n_perms
    [~, order] = sort(random_values(pi, :), 2);
    shuffled_cols(pi, :) = cols(order);
end
end

function shuffled_mtx = shuffle_matrix_rows(mtx, n_perms)
[n_rows, n_cols] = size(mtx);
shuffled_mtx = zeros(n_rows, n_cols, n_perms, 'int32');
random_values = rand(n_rows, n_cols, n_perms);

for ri = 1:n_rows
    current_row = mtx(ri, :);
    for pi = 1:n_perms
        [~, order] = sort(random_values(ri, :, pi), 2);
        shuffled_mtx(ri, :, pi) = current_row(order);
    end
end
end

function mi = mi_calc_core(base_cols, shifted_cols, window_dur, n_delays, n_bins, delay_offsets, hist_size, bin_row)
base_bins = int32(bin_row(double(base_cols)).');
shifted_bins = int32(reshape(bin_row(double(shifted_cols(:))), window_dur, n_delays));

pair_idx = base_bins .* int32(n_bins) + shifted_bins;
flat_idx = pair_idx + delay_offsets;

hf = accumarray(double(flat_idx(:)) + 1, 1, [double(n_delays * hist_size), 1]);
h3 = reshape(hf, n_bins, n_bins, n_delays);

hr = sum(h3, 2);
hc = sum(h3, 1);

pj = sum(sum(phi_counts(h3), 1), 2);
pr = sum(phi_counts(hr), 1);
pc = sum(phi_counts(hc), 2);

mi = log(window_dur) + (pj - pr - pc) ./ window_dur;
mi = reshape(mi, 1, []);
end

function v = phi_counts(n)
v = zeros(size(n), 'double');
mask = n > 0;
d = double(n(mask));
v(mask) = d .* log(d);
end
