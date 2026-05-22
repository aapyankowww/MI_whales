function [mi_window, shift_stats] = calc_window_mi_matlab(bin_matrix, window_start_frame, mi_constants, perm_cache)
%CALC_WINDOW_MI_MATLAB MATLAB-реализация MI для одного окна.

[n_freqs, ~] = size(bin_matrix);
window_dur = mi_constants.window_dur_frames;
n_delays = mi_constants.n_delays;
dt_frames = double(mi_constants.dt_frames_int32(:).');
base_cols = double(window_start_frame) + (0:window_dur-1);

mi_window = zeros(n_freqs, n_delays, 'double');
if perm_cache.n_perms > 0
    shift_mean = zeros(n_freqs, n_delays, 'double');
    shift_median = zeros(n_freqs, n_delays, 'double');
    shift_std = zeros(n_freqs, n_delays, 'double');
else
    shift_mean = [];
    shift_median = [];
    shift_std = [];
end

base_bins_by_freq = bin_matrix(:, base_cols);
shifted_bins_by_freq = zeros(n_freqs, window_dur, n_delays, class(bin_matrix));
for di = 1:n_delays
    shifted_bins_by_freq(:, :, di) = bin_matrix(:, base_cols + dt_frames(di));
end

for fi = 1:n_freqs
    base_bins = int32(base_bins_by_freq(fi, :)).';
    shifted_bins = int32(reshape(shifted_bins_by_freq(fi, :, :), window_dur, n_delays));
    mi_window(fi, :) = mi_calc_from_bins(base_bins, shifted_bins, mi_constants);

    if perm_cache.n_perms > 0
        perm_values = zeros(n_delays, perm_cache.n_perms, 'double');
        for pi = 1:perm_cache.n_perms
            base_perm = base_bins(perm_cache.base_orders(pi, :));
            shifted_perm = shifted_bins(double(perm_cache.shifted_linear_idx(:, :, pi)));
            perm_values(:, pi) = mi_calc_from_bins(base_perm, shifted_perm, mi_constants).';
        end

        shift_mean(fi, :) = mean(perm_values, 2).';
        shift_median(fi, :) = median(perm_values, 2).';
        shift_std(fi, :) = std(perm_values, 0, 2).';
    end
end

if perm_cache.n_perms > 0
    shift_stats = struct( ...
        'count', perm_cache.n_perms, ...
        'mean', shift_mean, ...
        'median', shift_median, ...
        'std', shift_std);
else
    shift_stats = [];
end
end

function mi = mi_calc_from_bins(base_bins, shifted_bins, mi_constants)
pair_idx = base_bins .* int32(mi_constants.n_bins) + shifted_bins;
flat_idx = pair_idx + mi_constants.delay_offsets;

hf = accumarray(double(flat_idx(:)) + 1, 1, [double(mi_constants.n_delays * mi_constants.hist_size), 1]);
h3 = reshape(hf, mi_constants.n_bins, mi_constants.n_bins, mi_constants.n_delays);

hr = sum(h3, 2);
hc = sum(h3, 1);

pj = sum(sum(phi_counts(h3, mi_constants.phi_lut), 1), 2);
pr = sum(phi_counts(hr, mi_constants.phi_lut), 1);
pc = sum(phi_counts(hc, mi_constants.phi_lut), 2);

mi = mi_constants.log_window_dur + (pj - pr - pc) ./ double(mi_constants.window_dur_frames);
mi = reshape(mi, 1, []);
end

function v = phi_counts(n, phi_lut)
v = phi_lut(double(n) + 1);
end
