function summary = process_plain_file_global_binning( ...
    audio_file, output_dir, ...
    frequency_mode, target_hz, range_hz, ...
    binning_type, n_bins, ...
    max_delay_sec, window_duration_sec, n_perms, ...
    save_window_matrices, window_matrix_mat_format, ...
    save_file_level_tensor, write_tensor_shards, max_tensor_shard_size_mb, tensor_shard_mat_format, ...
    save_segment_preview, ci_level, run_metadata, use_mex_backend)
%PROCESS_PLAIN_FILE_GLOBAL_BINNING
% Обрабатывает один WAV-файл целиком:
% 1) считает биннинг по всему файлу;
% 2) считает MI-матрицы по каждому временному окну;
% 3) по флагу сохраняет матрицы каждого окна отдельно.

if ~isfolder(output_dir)
    mkdir(output_dir);
end

file_total_tic = tic;
file_segment = build_full_file_segment(audio_file);
[~, file_id, ~] = fileparts(audio_file);
file_id = string(file_id);

timing = struct();
fprintf('  [%s] FFT pass 1...\n', file_id);

pass1_tic = tic;
fft_pass1 = fft_calc(file_segment);
timing.fft_pass1_sec = toc(pass1_tic);
fprintf('  [%s] FFT pass 1: %.2f c\n', file_id, timing.fft_pass1_sec);

[selected_idx, selected_freq_hz, freq_band_hz, selection_meta] = ...
    select_frequency_bins(fft_pass1.freq_hz, frequency_mode, target_hz, range_hz);
selected_db_pass1 = fft_pass1.spectrogram_db(selected_idx, :);

binning_tic = tic;
switch lower(string(binning_type))
    case "quantile"
        [~, bin_edges, binning_meta] = binning_quantile(selected_db_pass1, n_bins);
    case "uniform"
        [~, bin_edges, binning_meta] = binning_uniform(selected_db_pass1, n_bins);
    otherwise
        error('Неподдерживаемый тип бининга: %s', string(binning_type));
end
timing.binning_sec = toc(binning_tic);
fprintf('  [%s] Биннинг по полному файлу: %.2f c\n', file_id, timing.binning_sec);

binning_meta.scope = "full_file";
binning_meta.source_file = string(audio_file);
binning_meta.selected_frequency_indices = selected_idx;
binning_meta.selected_frequency_hz = selected_freq_hz;
binning_meta.selection_meta = selection_meta;
binning_meta.bin_edges = bin_edges;
binning_meta.edge_count = numel(bin_edges);
clear selected_db_pass1 fft_pass1;

fprintf('  [%s] FFT pass 2...\n', file_id);
pass2_tic = tic;
fft_result = fft_calc(file_segment);
timing.fft_pass2_sec = toc(pass2_tic);
fprintf('  [%s] FFT pass 2: %.2f c\n', file_id, timing.fft_pass2_sec);

selected_db_pass2 = fft_result.spectrogram_db(selected_idx, :);
bin_matrix = apply_binning_edges(selected_db_pass2, bin_edges, n_bins);
schedule = build_window_schedule(fft_result, max_delay_sec, window_duration_sec, file_segment.id);
perm_cache = precompute_permutation_cache(schedule.window_dur_frames, numel(schedule.dt_frames), n_perms);
mi_constants = build_mi_constants(n_bins, schedule.window_dur_frames, schedule.dt_frames_int32);
[backend_mode, backend_used, backend_message] = resolve_window_backend(use_mex_backend);
if strlength(backend_message) > 0
    fprintf('  [%s] %s\n', file_id, backend_message);
end
fprintf('  [%s] Backend окна: %s\n', file_id, backend_used);

n_freqs = size(bin_matrix, 1);
n_delays = numel(schedule.dt_frames);
n_windows = numel(schedule.requested_window_start_sec);

window_results = repmat(empty_window_result(), n_windows, 1);
window_axes = struct( ...
    'dt_frames', schedule.dt_frames, ...
    'dt_sec', schedule.dt_sec, ...
    'selected_freq_idx', selected_idx, ...
    'selected_freq_hz', selected_freq_hz, ...
    'freq_band_hz', freq_band_hz);

profile_stats = init_running_stats(n_delays);
if n_perms > 0
    shift_profile_stats = init_running_stats(n_delays);
else
    shift_profile_stats = struct();
end

if save_file_level_tensor
    file_mi_values = zeros(n_freqs, n_delays, n_windows, 'double');
    if n_perms > 0
        file_shift_stats = init_file_shift_stats(n_freqs, n_delays, n_windows);
    else
        file_shift_stats = [];
    end
else
    file_mi_values = [];
    file_shift_stats = [];
end

timing.mi_windows_sec = 0;
timing.window_save_sec = 0;

for wi = 1:n_windows
    mi_tic = tic;
    [mi_window, shift_stats] = calc_window_mi_backend( ...
        bin_matrix, schedule.window_start_frames(wi), mi_constants, perm_cache, backend_mode);
    window_mi_sec = toc(mi_tic);
    timing.mi_windows_sec = timing.mi_windows_sec + window_mi_sec;

    profile_stats = update_running_stats(profile_stats, mean(mi_window, 1));
    if n_perms > 0
        shift_profile_stats = update_running_stats( ...
            shift_profile_stats, mean(shift_stats.mean, 1));
    end

    if save_file_level_tensor
        file_mi_values(:, :, wi) = mi_window;
        if n_perms > 0
            file_shift_stats = assign_file_shift_stats(file_shift_stats, shift_stats, wi);
        end
    end

    window_meta = struct();
    window_meta.window_index = wi;
    window_meta.requested_window_start_sec = schedule.requested_window_start_sec(wi);
    window_meta.requested_window_end_sec = schedule.requested_window_end_sec(wi);
    window_meta.requested_context_start_sec = schedule.requested_context_start_sec(wi);
    window_meta.requested_context_end_sec = schedule.requested_context_end_sec(wi);
    window_meta.fft_window_start_frame = double(schedule.window_start_frames(wi));
    window_meta.fft_window_end_frame = double(schedule.window_start_frames(wi) + schedule.window_dur_frames - 1);
    window_meta.fft_window_start_sec = schedule.fft_window_start_sec(wi);
    window_meta.fft_window_end_sec = schedule.fft_window_end_sec(wi);
    window_meta.fft_context_start_frame = double(schedule.window_start_frames(wi) + schedule.dt_frames_int32(1));
    window_meta.fft_context_end_frame = double(schedule.window_start_frames(wi) + schedule.window_dur_frames - 1 + schedule.dt_frames_int32(end));
    window_meta.fft_context_start_sec = schedule.fft_context_start_sec(wi);
    window_meta.fft_context_end_sec = schedule.fft_context_end_sec(wi);
    window_meta.source_audio_file = string(audio_file);

    mat_path = "";
    window_save_sec = 0;
    if save_window_matrices
        save_tic = tic;
        mat_path = save_window_mi_result( ...
            output_dir, file_id, wi, mi_window, shift_stats, window_meta, window_axes, run_metadata, window_matrix_mat_format);
        window_save_sec = toc(save_tic);
        timing.window_save_sec = timing.window_save_sec + window_save_sec;
    end

    window_results(wi).window_index = wi;
    window_results(wi).mat_path = string(mat_path);
    window_results(wi).window_start_sec = window_meta.requested_window_start_sec;
    window_results(wi).window_end_sec = window_meta.requested_window_end_sec;
    window_results(wi).context_start_sec = window_meta.requested_context_start_sec;
    window_results(wi).context_end_sec = window_meta.requested_context_end_sec;

    fprintf('  [%s] Окно %d/%d: MI %.2f c | save %.2f c | t=[%.2f, %.2f] c\n', ...
        file_id, wi, n_windows, window_mi_sec, window_save_sec, ...
        window_meta.requested_window_start_sec, window_meta.requested_window_end_sec);
end

timing.preview_sec = 0;
preview_path = "";
if save_segment_preview
    preview_tic = tic;
    preview_path = fullfile(output_dir, sprintf('%s_file_preview.png', file_id));
    plot_segment_preview(file_segment, fft_result, preview_path);
    timing.preview_sec = toc(preview_tic);
end

file_level_result = struct();
file_level_result.dt_frames = schedule.dt_frames;
file_level_result.dt_sec = schedule.dt_sec;
file_level_result.selected_freq_idx = selected_idx;
file_level_result.selected_freq_hz = selected_freq_hz;
file_level_result.freq_band_hz = freq_band_hz;
file_level_result.requested_window_start_sec = schedule.requested_window_start_sec;
file_level_result.requested_window_end_sec = schedule.requested_window_end_sec;
file_level_result.fft_window_start_sec = schedule.fft_window_start_sec;
file_level_result.fft_window_end_sec = schedule.fft_window_end_sec;
file_level_result.window_start_frames = double(schedule.window_start_frames);
file_level_result.window_end_frames = double(schedule.window_start_frames + schedule.window_dur_frames - 1);
file_level_result.window_duration_frames = schedule.window_dur_frames;
file_level_result.window_duration_sec = window_duration_sec;
file_level_result.window_step_sec = schedule.window_step_sec;
file_level_result.n_windows = n_windows;
file_level_result.n_perms = n_perms;
file_level_result.mi_profile_mean = finalize_running_stats(profile_stats);
if n_perms > 0
    file_level_result.shift_profile_mean = finalize_running_stats(shift_profile_stats);
else
    file_level_result.shift_profile_mean = [];
end
file_level_result.shift_window_stats = file_shift_stats;
file_level_result.save_file_level_tensor = logical(save_file_level_tensor);
file_level_result.mi_values = file_mi_values;
file_level_result.shift_mi = [];
file_level_result.write_tensor_shards = logical(write_tensor_shards);
file_level_result.max_tensor_shard_size_mb = max_tensor_shard_size_mb;
file_level_result.tensor_shard_mat_format = string(tensor_shard_mat_format);
file_level_result.save_window_matrices = logical(save_window_matrices);
file_level_result.ci_level = ci_level;
file_level_result.permutation_reuse = perm_cache.reused;
file_level_result.window_backend = backend_used;
file_level_result.window_backend_requested = string(logical(use_mex_backend));

timing.total_sec_pre_save = toc(file_total_tic);
file_result_tic = tic;
file_result_path = save_plain_file_result( ...
    output_dir, file_id, file_segment, fft_result, binning_meta, ...
    file_level_result, window_results, timing, run_metadata, tensor_shard_mat_format);
timing.file_result_save_sec = toc(file_result_tic);
timing.total_sec = timing.total_sec_pre_save + timing.file_result_save_sec;
save(file_result_path, 'timing', '-append');
fprintf('  [%s] Итого по файлу: %.2f c | окна=%d | save_result=%.2f c\n', ...
    file_id, timing.total_sec, n_windows, timing.file_result_save_sec);

summary = struct();
summary.file_id = file_id;
summary.audio_file = string(audio_file);
summary.file_result_path = string(file_result_path);
summary.preview_path = string(preview_path);
summary.window_count = n_windows;
summary.window_results = window_results;
summary.selected_freq_hz = selected_freq_hz;
summary.freq_band_hz = freq_band_hz;
summary.dt_sec = schedule.dt_sec;
summary.timing = timing;
summary.window_backend = backend_used;
end

function schedule = build_window_schedule(fft_result, max_delay_sec, window_duration_sec, segment_id)
frame_step_sec = infer_frame_step_sec(fft_result);
dt_frames = -round(max_delay_sec / frame_step_sec):round(max_delay_sec / frame_step_sec);
dt_frames_int32 = int32(dt_frames);
duration_sec = numel(fft_result.waveform) / fft_result.sample_rate;
window_step_sec = window_duration_sec;
window_dur_frames = round(window_duration_sec / frame_step_sec);

first_start_sec = ceil(max_delay_sec / window_step_sec) * window_step_sec;
last_start_sec = duration_sec - max_delay_sec - window_duration_sec;

if last_start_sec < first_start_sec
    error(['Сегмент %s слишком короткий для выбранных параметров MI. ' ...
        'Требуется больше временных кадров FFT с запасом для лагов в обе стороны.'], segment_id);
end

requested_window_start_sec = first_start_sec:window_step_sec:last_start_sec;
requested_window_start_sec = requested_window_start_sec(:).';
requested_window_end_sec = requested_window_start_sec + window_duration_sec;
requested_context_start_sec = requested_window_start_sec - max_delay_sec;
requested_context_end_sec = requested_window_end_sec + max_delay_sec;

n_windows = numel(requested_window_start_sec);
fft_window_start_sec = zeros(1, n_windows);
fft_window_end_sec = zeros(1, n_windows);
fft_context_start_sec = zeros(1, n_windows);
fft_context_end_sec = zeros(1, n_windows);
window_start_frames = zeros(1, n_windows, 'int32');
valid_mask = false(1, n_windows);

for wi = 1:n_windows
    first_col = find(fft_result.time_sec >= requested_window_start_sec(wi), 1, 'first');
    if isempty(first_col)
        continue;
    end
    last_col = first_col + window_dur_frames - 1;
    current_cols = int32(first_col:last_col);

    if current_cols(1) + dt_frames_int32(1) < 1 || current_cols(end) + dt_frames_int32(end) > numel(fft_result.time_sec)
        continue;
    end

    window_start_frames(wi) = current_cols(1);
    fft_window_start_sec(wi) = fft_result.time_sec(double(current_cols(1)));
    fft_window_end_sec(wi) = fft_result.time_sec(double(current_cols(end)));
    fft_context_start_sec(wi) = fft_result.time_sec(double(current_cols(1) + dt_frames_int32(1)));
    fft_context_end_sec(wi) = fft_result.time_sec(double(current_cols(end) + dt_frames_int32(end)));
    valid_mask(wi) = true;
end

if ~any(valid_mask)
    error(['Сегмент %s слишком короткий для выбранных параметров MI. ' ...
        'Требуется больше временных кадров FFT с запасом для лагов в обе стороны.'], segment_id);
end

requested_window_start_sec = requested_window_start_sec(valid_mask);
requested_window_end_sec = requested_window_end_sec(valid_mask);
requested_context_start_sec = requested_context_start_sec(valid_mask);
requested_context_end_sec = requested_context_end_sec(valid_mask);
fft_window_start_sec = fft_window_start_sec(valid_mask);
fft_window_end_sec = fft_window_end_sec(valid_mask);
fft_context_start_sec = fft_context_start_sec(valid_mask);
fft_context_end_sec = fft_context_end_sec(valid_mask);
window_start_frames = window_start_frames(valid_mask);

schedule = struct();
schedule.frame_step_sec = frame_step_sec;
schedule.window_step_sec = window_step_sec;
schedule.window_dur_frames = window_dur_frames;
schedule.dt_frames = dt_frames;
schedule.dt_frames_int32 = dt_frames_int32(:).';
schedule.dt_sec = double(dt_frames_int32) * frame_step_sec;
schedule.window_start_frames = window_start_frames;
schedule.requested_window_start_sec = requested_window_start_sec;
schedule.requested_window_end_sec = requested_window_end_sec;
schedule.requested_context_start_sec = requested_context_start_sec;
schedule.requested_context_end_sec = requested_context_end_sec;
schedule.fft_window_start_sec = fft_window_start_sec;
schedule.fft_window_end_sec = fft_window_end_sec;
schedule.fft_context_start_sec = fft_context_start_sec;
schedule.fft_context_end_sec = fft_context_end_sec;
end

function perm_cache = precompute_permutation_cache(window_dur_frames, n_delays, n_perms)
perm_cache = struct();
perm_cache.reused = n_perms > 0;
perm_cache.n_perms = n_perms;

if n_perms <= 0
    perm_cache.base_orders = zeros(0, window_dur_frames, 'int32');
    perm_cache.shifted_linear_idx = zeros(window_dur_frames, n_delays, 0, 'int32');
    return;
end

base_orders = zeros(n_perms, window_dur_frames, 'int32');
shifted_linear_idx = zeros(window_dur_frames, n_delays, n_perms, 'int32');
delay_offsets = reshape(int32((0:n_delays-1) * window_dur_frames), 1, n_delays);

for pi = 1:n_perms
    [~, base_order] = sort(rand(1, window_dur_frames), 2);
    base_orders(pi, :) = int32(base_order);

    [~, shifted_order] = sort(rand(window_dur_frames, n_delays), 1);
    shifted_linear_idx(:, :, pi) = int32(shifted_order) + delay_offsets;
end

perm_cache.base_orders = base_orders;
perm_cache.shifted_linear_idx = shifted_linear_idx;
end

function mi_constants = build_mi_constants(n_bins, window_dur_frames, dt_frames)
mi_constants = struct();
mi_constants.n_bins = n_bins;
mi_constants.window_dur_frames = window_dur_frames;
mi_constants.n_delays = numel(dt_frames);
mi_constants.hist_size = int32(n_bins * n_bins);
mi_constants.delay_offsets = int32(0:mi_constants.n_delays-1) .* mi_constants.hist_size;
mi_constants.dt_frames_int32 = int32(dt_frames(:).');
mi_constants.phi_lut = zeros(window_dur_frames + 1, 1, 'double');
if window_dur_frames > 0
    counts = (1:window_dur_frames).';
    mi_constants.phi_lut(2:end) = counts .* log(counts);
end
mi_constants.log_window_dur = log(double(window_dur_frames));
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

function [backend_mode, backend_used, message_text] = resolve_window_backend(use_mex_backend)
message_text = "";

if ~use_mex_backend
    backend_mode = "matlab";
    backend_used = "matlab";
    return;
end

if exist('mi_window_mex_v2', 'file') == 3
    backend_mode = "mex";
    backend_used = "mex";
    return;
end

[ok, mex_path, compile_message] = compile_mi_window_mex();
if ok && exist(mex_path, 'file') == 2
    clear('mi_window_mex_v2');
    backend_mode = "mex";
    backend_used = "mex";
    message_text = "MEX backend собран и будет использован.";
else
    backend_mode = "matlab";
    backend_used = "matlab";
    message_text = "MEX backend недоступен, используется MATLAB backend. " + string(compile_message);
end
end

function stats = init_running_stats(n_delays)
stats = struct();
stats.count = 0;
stats.mean = zeros(1, n_delays);
stats.m2 = zeros(1, n_delays);
end

function stats = update_running_stats(stats, x)
stats.count = stats.count + 1;
delta = x - stats.mean;
stats.mean = stats.mean + delta / stats.count;
delta2 = x - stats.mean;
stats.m2 = stats.m2 + delta .* delta2;
end

function result = finalize_running_stats(stats)
result = struct();
result.count = stats.count;
result.mean = stats.mean;
if stats.count > 1
    result.variance = stats.m2 / (stats.count - 1);
else
    result.variance = zeros(size(stats.mean));
end
end

function item = empty_window_result()
item = struct( ...
    'window_index', [], ...
    'mat_path', "", ...
    'window_start_sec', [], ...
    'window_end_sec', [], ...
    'context_start_sec', [], ...
    'context_end_sec', []);
end

function file_shift_stats = init_file_shift_stats(n_freqs, n_delays, n_windows)
file_shift_stats = struct();
file_shift_stats.mean = zeros(n_freqs, n_delays, n_windows, 'double');
file_shift_stats.median = zeros(n_freqs, n_delays, n_windows, 'double');
file_shift_stats.std = zeros(n_freqs, n_delays, n_windows, 'double');
file_shift_stats.count = [];
end

function file_shift_stats = assign_file_shift_stats(file_shift_stats, shift_stats, window_index)
if isempty(file_shift_stats.count)
    file_shift_stats.count = shift_stats.count;
end

file_shift_stats.mean(:, :, window_index) = shift_stats.mean;
file_shift_stats.median(:, :, window_index) = shift_stats.median;
file_shift_stats.std(:, :, window_index) = shift_stats.std;
end
