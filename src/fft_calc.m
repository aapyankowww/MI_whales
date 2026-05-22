function fft_result = fft_calc(segment)
%FFT_CALC Читает сегмент и строит спектрограмму с внутренними default-параметрами.

params = default_fft_params();

if isempty(segment.audio)
    [x, fs] = audioread(segment.audio_file, [segment.sample_start_idx, segment.sample_end_idx]);
else
    x = segment.audio;
    fs = segment.sample_rate;
end

x = ensure_mono(x);
x = x(:);

if numel(x) < 32
    error('Сегмент %s слишком короткий для FFT-анализа', segment.id);
end

window_samples = min(params.window_samples, numel(x));
overlap_samples = min(params.overlap_samples, max(0, window_samples - 1));
nfft = max(params.nfft, 2^nextpow2(window_samples));
window_fn = hann(window_samples, 'periodic');

[S, F, T] = spectrogram(x, window_fn, overlap_samples, nfft, fs);
power_matrix = abs(S) .^ 2;
db_matrix = 10 * log10(power_matrix + eps);

if numel(F) > params.target_freq_bin_count
    keep_idx = 1:params.target_freq_bin_count;
    F = F(keep_idx);
    power_matrix = power_matrix(keep_idx, :);
    db_matrix = db_matrix(keep_idx, :);
end

fft_result = struct();
fft_result.segment_id = segment.id;
fft_result.sample_rate = fs;
fft_result.waveform = x;
fft_result.waveform_time_sec = (0:numel(x)-1).' / fs;
fft_result.freq_hz = F;
fft_result.time_sec = T;
fft_result.spectrogram_power = power_matrix;
fft_result.spectrogram_db = db_matrix;
fft_result.fft_params = struct( ...
    'window_samples', window_samples, ...
    'overlap_samples', overlap_samples, ...
    'nfft', nfft, ...
    'target_freq_bin_count', params.target_freq_bin_count, ...
    'actual_freq_bin_count', numel(F), ...
    'window_name', params.window_name, ...
    'channel_mode', params.channel_mode);
end

function params = default_fft_params()
params = struct();
params.window_samples = 1024;
params.overlap_samples = 512;
params.nfft = 1024;
params.target_freq_bin_count = 512;
params.window_name = 'hann_periodic';
params.channel_mode = 'mono_mean';
end
