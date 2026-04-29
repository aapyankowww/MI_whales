function labels = read_audacity_labels(file_path)
%READ_AUDACITY_LABELS Читает интервальную разметку Audacity из TXT.

if ~isfile(file_path)
    error('Файл разметки не найден: %s', file_path);
end

lines = readlines(file_path);
lines = lines(strlength(strtrim(lines)) > 0);

if isempty(lines)
    labels = repmat(struct('start_sec', [], 'end_sec', [], 'label_text', ""), 0, 1);
    return;
end

delimiter = detect_delimiter(lines(1));
[has_header, start_col, end_col, label_col] = detect_header_layout(lines(1), delimiter);

data_start_idx = 1;
if has_header
    data_start_idx = 2;
end

template = struct('start_sec', [], 'end_sec', [], 'label_text', "");
labels = repmat(template, 0, 1);

for i = data_start_idx:numel(lines)
    parts = split_line(lines(i), delimiter);
    if numel(parts) < 2
        error('Некорректная строка %d в файле %s', i, file_path);
    end

    if has_header
        if numel(parts) < max([start_col, end_col, label_col])
            error('В строке %d файла %s меньше столбцов, чем ожидается по заголовку', i, file_path);
        end
        start_token = parts(start_col);
        end_token = parts(end_col);
        label_tokens = parts(label_col:end);
    else
        start_token = parts(1);
        end_token = parts(2);
        label_tokens = parts(3:end);
    end

    start_sec = str2double(start_token);
    end_sec = str2double(end_token);
    if isnan(start_sec) || isnan(end_sec)
        error('Не удалось прочитать start/end в строке %d файла %s', i, file_path);
    end
    if end_sec < start_sec
        error('Интервал с end < start в строке %d файла %s', i, file_path);
    end

    label_text = "";
    if ~isempty(label_tokens)
        label_text = join(label_tokens, delimiter);
    end

    labels(end + 1, 1) = struct( ... %#ok<AGROW>
        'start_sec', start_sec, ...
        'end_sec', end_sec, ...
        'label_text', string(label_text));
end
end

function delimiter = detect_delimiter(line_value)
if contains(line_value, sprintf('\t'))
    delimiter = sprintf('\t');
elseif contains(line_value, ',')
    delimiter = ',';
else
    delimiter = sprintf('\t');
end
end

function [has_header, start_col, end_col, label_col] = detect_header_layout(line_value, delimiter)
parts = split_line(line_value, delimiter);
parts = lower(strtrim(parts));

has_header = false;
start_col = 1;
end_col = 2;
label_col = 3;

if numel(parts) < 3
    return;
end

if parts(1) == "start" && any(parts == "stop")
    has_header = true;
    start_col = 1;
    end_col = find(parts == "stop", 1, 'first');
    label_col = numel(parts);
end
end

function parts = split_line(line_value, delimiter)
parts = split(line_value, delimiter);
parts = strtrim(parts);
end
