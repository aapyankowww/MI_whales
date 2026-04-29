function dataset = prepare_data(audio_path, label_path, pad_left_sec, pad_right_sec, segment_duration_sec, segment_overlap_sec)
%PREPARE_DATA Подготавливает сегменты для annotated/plain режимов.

audio_path = string(audio_path);
label_path = string(label_path);

audio_files = find_audio_files(audio_path);
mode = "plain";
if strlength(label_path) > 0
    mode = "annotated";
end

segments = repmat(empty_segment(), 0, 1);

for ai = 1:numel(audio_files)
    audio_file = audio_files(ai);
    switch mode
        case "annotated"
            label_file = find_matching_label(audio_file, label_path);
            labels = read_audacity_labels(label_file);
            info = audioinfo(audio_file);
            for li = 1:numel(labels)
                segment = make_segment_from_interval( ...
                    audio_file, label_file, info, labels(li), pad_left_sec, pad_right_sec, li);
                segments(end + 1, 1) = segment; %#ok<AGROW>
            end
        case "plain"
            plain_segments = make_plain_segments(audio_file, segment_duration_sec, segment_overlap_sec);
            segments = [segments; plain_segments(:)]; %#ok<AGROW>
        otherwise
            error('Неподдерживаемый режим: %s', mode);
    end
end

dataset = struct();
dataset.mode = mode;
dataset.source_audio = audio_files;
dataset.source_labels = label_path;
dataset.created_at = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
dataset.segments = segments;
end

function audio_files = find_audio_files(audio_path)
if isfile(audio_path)
    audio_files = string(audio_path);
    return;
end

if ~isfolder(audio_path)
    error('Путь к аудио не существует: %s', audio_path);
end

listing = dir(fullfile(audio_path, '*.wav'));
listing = [listing; dir(fullfile(audio_path, '*.WAV'))];

if isempty(listing)
    error('В папке не найдено WAV-файлов: %s', audio_path);
end

audio_files = strings(numel(listing), 1);
for i = 1:numel(listing)
    audio_files(i) = string(fullfile(listing(i).folder, listing(i).name));
end
audio_files = unique(audio_files, 'stable');
end

function label_file = find_matching_label(audio_file, label_dir)
[~, base_name, ~] = fileparts(audio_file);
direct_match = fullfile(label_dir, base_name + ".txt");
upper_match = fullfile(label_dir, base_name + ".TXT");

if isfile(direct_match)
    label_file = string(direct_match);
elseif isfile(upper_match)
    label_file = string(upper_match);
else
    error('Для аудио %s не найден matching label-файл в %s', audio_file, label_dir);
end
end

function segment = empty_segment()
segment = struct( ...
    'id', "", ...
    'audio_file', "", ...
    'label_file', "", ...
    'label_text', "", ...
    't_start_sec', [], ...
    't_end_sec', [], ...
    't_center_sec', [], ...
    'pad_left_sec', [], ...
    'pad_right_sec', [], ...
    'segment_start_sec', [], ...
    'segment_end_sec', [], ...
    'sample_start_idx', [], ...
    'sample_end_idx', [], ...
    'sample_rate', [], ...
    'num_samples', [], ...
    'audio', []);
end
