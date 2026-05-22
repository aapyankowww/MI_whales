function audio_files = find_audio_files(audio_path)
%FIND_AUDIO_FILES Возвращает один WAV-файл или список WAV-файлов из папки.

audio_path = string(audio_path);

if isfile(audio_path)
    audio_files = audio_path;
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
