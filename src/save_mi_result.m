function [mat_path, payload] = save_mi_result(segment, fft_result, binning_meta, mi_result, output_dir, run_metadata)
%SAVE_MI_RESULT Сохраняет self-contained результат расчета.

dataset_meta = segment;
dataset_meta.audio = [];

fft_result_meta = struct();
fft_result_meta.segment_id = fft_result.segment_id;
fft_result_meta.sample_rate = fft_result.sample_rate;
fft_result_meta.freq_hz = fft_result.freq_hz;
fft_result_meta.time_sec = fft_result.time_sec;
fft_result_meta.spectrogram_size = size(fft_result.spectrogram_db);
fft_result_meta.fft_params = fft_result.fft_params;

payload = struct();
payload.dataset_meta = dataset_meta;
payload.fft_result_meta = fft_result_meta;
payload.binning_meta = binning_meta;
payload.mi_result = mi_result;
payload.run_timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
payload.code_version = "mi_profiles_repository_local_v1";
payload.run_metadata = run_metadata;

mat_path = fullfile(output_dir, sprintf('%s_result.mat', segment.id));
save(mat_path, '-struct', 'payload');
end
