% RUN_LARGE_FOLDER_UNIFORM_PM10
% Запуск для большой папки аудио:
% - равномерный биннинг
% - окно MI = 1 секунда
% - лаги от -10 до +10 секунд

repo_root = fileparts(mfilename('fullpath'));
addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'src')));

%% ======================== ПУТИ ========================
% Основной сценарий этого файла: запуск по большой папке с WAV-файлами.
% Укажите здесь путь к папке. При необходимости можно задать и один WAV-файл.
audio_path = "C:\Users\redac\OneDrive\Documents\MATLAB\project\recordings";
% audio_path = fullfile(repo_root, '..', '12-22.WAV');
label_path = "";
output_dir = fullfile(repo_root, 'results', 'large_folder_uniform_pm10_mex');

if audio_path == "C:\path\to\large_audio_folder"
    error('Укажите реальный путь к папке с WAV-файлами в переменной audio_path.');
end

%% =================== ПОДГОТОВКА ДАННЫХ ===================
pad_left_sec = 5.0;
pad_right_sec = 5.0;
segment_duration_sec = 30.0;
segment_overlap_sec = 0.0;

%% ================== ВЫБОР ЧАСТОТЫ ==================
frequency_mode = "band";        % "single" или "band"
target_hz = 1000;
range_hz = [0 22050];

%% ======================= БИННИНГ =======================
binning_type = "uniform";
n_bins = 10;

%% ======================== MI ========================
max_delay_sec = 10.0;
window_duration_sec = 1.0;
n_perms = 10;
% Профиль будет рассчитан по лагам от -10 до +10 секунд.

%% ======================= ГРАФИКИ =======================
save_segment_preview = false;
ci_level = 0.95;

%% ===================== СОХРАНЕНИЕ ======================
write_tensor_shards = true;
max_tensor_shard_size_mb = 1024;
tensor_shard_mat_format = '-v7.3';

%% ================== PLAIN-РЕЖИМ ==================
plain_processing_mode = "file_global_binning";
save_window_matrices = true;
save_file_level_tensor = false;
window_matrix_mat_format = '-v7.3';
use_mex_backend = true;

summary = run_mi_pipeline_core( ...
    audio_path, ...
    label_path, ...
    output_dir, ...
    pad_left_sec, ...
    pad_right_sec, ...
    segment_duration_sec, ...
    segment_overlap_sec, ...
    frequency_mode, ...
    target_hz, ...
    range_hz, ...
    binning_type, ...
    n_bins, ...
    max_delay_sec, ...
    window_duration_sec, ...
    n_perms, ...
    save_segment_preview, ...
    ci_level, ...
    write_tensor_shards, ...
    max_tensor_shard_size_mb, ...
    tensor_shard_mat_format, ...
    plain_processing_mode, ...
    save_window_matrices, ...
    save_file_level_tensor, ...
    window_matrix_mat_format, ...
    use_mex_backend);
disp(summary.output_dir);
