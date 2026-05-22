function mat_path = save_plain_file_result(output_dir, file_id, file_meta, fft_result, binning_meta, file_level_result, window_manifest, timing, run_metadata, mat_format)
%SAVE_PLAIN_FILE_RESULT Сохраняет file-level метаданные и манифест окон.

fft_result_meta = struct();
fft_result_meta.segment_id = fft_result.segment_id;
fft_result_meta.sample_rate = fft_result.sample_rate;
fft_result_meta.freq_hz = fft_result.freq_hz;
fft_result_meta.time_sec = fft_result.time_sec;
fft_result_meta.spectrogram_size = size(fft_result.spectrogram_db);
fft_result_meta.fft_params = fft_result.fft_params;

payload = struct();
payload.file_meta = file_meta;
payload.fft_result_meta = fft_result_meta;
payload.binning_meta = binning_meta;
payload.file_level_result = file_level_result;
payload.window_manifest = window_manifest;
payload.window_count = numel(window_manifest);
payload.timing = timing;
payload.run_metadata = run_metadata;
payload.run_timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
payload.code_version = "mi_profiles_repository_local_v1";

mat_path = fullfile(output_dir, sprintf('%s_file_result.mat', file_id));
save(mat_path, '-struct', 'payload', mat_format);
end
