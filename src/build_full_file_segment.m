function segment = build_full_file_segment(audio_file)
%BUILD_FULL_FILE_SEGMENT Строит сегмент, покрывающий весь WAV-файл.

info = audioinfo(audio_file);
[~, base_name, ~] = fileparts(audio_file);

segment = struct();
segment.id = string(base_name) + "_full";
segment.audio_file = string(audio_file);
segment.label_file = "";
segment.label_text = "";
segment.t_start_sec = [];
segment.t_end_sec = [];
segment.t_center_sec = info.Duration / 2;
segment.pad_left_sec = 0;
segment.pad_right_sec = 0;
segment.segment_start_sec = 0;
segment.segment_end_sec = info.Duration;
segment.sample_start_idx = 1;
segment.sample_end_idx = info.TotalSamples;
segment.sample_rate = info.SampleRate;
segment.num_samples = info.TotalSamples;
segment.audio = [];
end
