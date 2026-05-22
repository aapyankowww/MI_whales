function mat_path = save_window_mi_result(output_dir, file_id, window_index, mi_window, shift_stats, window_meta, axes_meta, run_metadata, mat_format)
%SAVE_WINDOW_MI_RESULT Сохраняет MI-матрицу отдельного окна в self-contained MAT.

payload = struct();
payload.mi_window = mi_window;
payload.shift_stats = shift_stats;
payload.window_meta = window_meta;
payload.axes_meta = axes_meta;
payload.run_metadata = run_metadata;
payload.run_timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
payload.code_version = "mi_profiles_repository_local_v1";

mat_path = fullfile(output_dir, sprintf('%s_window_%06d_result.mat', file_id, window_index));
save(mat_path, '-struct', 'payload', mat_format);
end
