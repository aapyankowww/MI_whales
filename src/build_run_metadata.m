function run_metadata = build_run_metadata( ...
    audio_path, label_path, output_dir, ...
    pad_left_sec, pad_right_sec, ...
    segment_duration_sec, segment_overlap_sec, ...
    frequency_mode, target_hz, range_hz, ...
    binning_type, n_bins, ...
    max_delay_sec, window_duration_sec, n_perms, ...
    save_segment_preview, ci_level, ...
    write_tensor_shards, max_tensor_shard_size_mb, tensor_shard_mat_format, ...
    plain_processing_mode, save_window_matrices, save_file_level_tensor, window_matrix_mat_format, ...
    use_mex_backend)
%BUILD_RUN_METADATA Собирает метаданные запуска из явных значений.

run_metadata = struct();
run_metadata.audio_path = string(audio_path);
run_metadata.label_path = string(label_path);
run_metadata.output_dir = string(output_dir);
run_metadata.pad_left_sec = pad_left_sec;
run_metadata.pad_right_sec = pad_right_sec;
run_metadata.segment_duration_sec = segment_duration_sec;
run_metadata.segment_overlap_sec = segment_overlap_sec;
run_metadata.frequency_mode = string(frequency_mode);
run_metadata.target_hz = target_hz;
run_metadata.range_hz = range_hz;
run_metadata.binning_type = string(binning_type);
run_metadata.n_bins = n_bins;
run_metadata.max_delay_sec = max_delay_sec;
run_metadata.window_duration_sec = window_duration_sec;
run_metadata.n_perms = n_perms;
run_metadata.save_segment_preview = logical(save_segment_preview);
run_metadata.ci_level = ci_level;
run_metadata.write_tensor_shards = logical(write_tensor_shards);
run_metadata.max_tensor_shard_size_mb = max_tensor_shard_size_mb;
run_metadata.tensor_shard_mat_format = string(tensor_shard_mat_format);
run_metadata.plain_processing_mode = string(plain_processing_mode);
run_metadata.save_window_matrices = logical(save_window_matrices);
run_metadata.save_file_level_tensor = logical(save_file_level_tensor);
run_metadata.window_matrix_mat_format = string(window_matrix_mat_format);
run_metadata.use_mex_backend = logical(use_mex_backend);
end
