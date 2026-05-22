function [mat_path, payload] = save_mi_result(segment, fft_result, binning_meta, mi_result, output_dir, run_metadata, write_tensor_shards, max_tensor_shard_size_mb, tensor_shard_mat_format)
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
payload.mi_result = prepare_mi_result_for_disk( ...
    mi_result, output_dir, segment.id, ...
    write_tensor_shards, max_tensor_shard_size_mb, tensor_shard_mat_format);
payload.run_timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
payload.code_version = "mi_profiles_repository_local_v1";
payload.run_metadata = run_metadata;

mat_path = fullfile(output_dir, sprintf('%s_result.mat', segment.id));
save(mat_path, '-struct', 'payload', '-v7.3');
end

function mi_result_to_save = prepare_mi_result_for_disk(mi_result, output_dir, segment_id, write_tensor_shards, max_tensor_shard_size_mb, tensor_shard_mat_format)
mi_result_to_save = mi_result;
if ~isfield(mi_result_to_save, 'shift_stats') || isempty(mi_result_to_save.shift_stats)
    mi_result_to_save.shift_stats = summarize_shift_tensor(mi_result_to_save.shift_mi, 3);
end

if ~write_tensor_shards
    mi_result_to_save.shift_mi = [];
    mi_result_to_save.tensor_shards = struct( ...
        'enabled', false, ...
        'mi_values', repmat(empty_shard_manifest(), 0, 1), ...
        'shift_mi', repmat(empty_shard_manifest(), 0, 1), ...
        'max_shard_size_mb', max_tensor_shard_size_mb, ...
        'mat_format', string(tensor_shard_mat_format));
    return;
end

mi_value_shards = write_tensor_shards_to_disk( ...
    mi_result.mi_values, output_dir, segment_id, 'mi_values', ...
    max_tensor_shard_size_mb, tensor_shard_mat_format);

mi_result_to_save.mi_values = [];
mi_result_to_save.shift_mi = [];
mi_result_to_save.tensor_shards = struct( ...
    'enabled', true, ...
    'mi_values', mi_value_shards, ...
    'shift_mi', repmat(empty_shard_manifest(), 0, 1), ...
    'max_shard_size_mb', max_tensor_shard_size_mb, ...
    'mat_format', string(tensor_shard_mat_format));
end

function shard_manifest = write_tensor_shards_to_disk(tensor_data, output_dir, segment_id, tensor_name, max_tensor_shard_size_mb, tensor_shard_mat_format)
if isempty(tensor_data)
    shard_manifest = repmat(empty_shard_manifest(), 0, 1);
    return;
end

bytes_info = whos('tensor_data');
total_bytes = double(bytes_info.bytes);
last_dim = size(tensor_data, ndims(tensor_data));
bytes_per_last_slice = total_bytes / max(1, last_dim);
max_shard_bytes = max_tensor_shard_size_mb * 1024 * 1024;
shard_last_dim = max(1, floor(max_shard_bytes / max(bytes_per_last_slice, 1)));
num_shards = ceil(last_dim / shard_last_dim);

shard_manifest = repmat(empty_shard_manifest(), num_shards, 1);

for shard_idx = 1:num_shards
    idx_start = (shard_idx - 1) * shard_last_dim + 1;
    idx_end = min(last_dim, shard_idx * shard_last_dim);

    indexer = repmat({':'}, 1, ndims(tensor_data));
    indexer{end} = idx_start:idx_end;
    tensor_shard = tensor_data(indexer{:});

    shard_file_path = fullfile(output_dir, sprintf('%s_%s_shard_%04d.mat', segment_id, tensor_name, shard_idx));
    original_size = size(tensor_data);
    shard_index_range = [idx_start, idx_end];
    save(shard_file_path, 'tensor_shard', 'tensor_name', 'original_size', 'shard_index_range', tensor_shard_mat_format);

    shard_manifest(shard_idx).tensor_name = string(tensor_name);
    shard_manifest(shard_idx).file_path = string(shard_file_path);
    shard_manifest(shard_idx).shard_index = shard_idx;
    shard_manifest(shard_idx).index_start = idx_start;
    shard_manifest(shard_idx).index_end = idx_end;
    shard_manifest(shard_idx).original_size = original_size;
end
end

function shard = empty_shard_manifest()
shard = struct( ...
    'tensor_name', "", ...
    'file_path', "", ...
    'shard_index', [], ...
    'index_start', [], ...
    'index_end', [], ...
    'original_size', []);
end
