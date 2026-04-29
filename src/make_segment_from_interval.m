function segment = make_segment_from_interval(audio_file, label_file, info, label_entry, pad_left_sec, pad_right_sec, segment_index)
%MAKE_SEGMENT_FROM_INTERVAL Формирует сегмент вокруг центра размеченного интервала.

center_sec = (label_entry.start_sec + label_entry.end_sec) / 2;
desired_start = center_sec - pad_left_sec;
desired_end = center_sec + pad_right_sec;
[segment_start, segment_end] = clamp_interval(desired_start, desired_end, 0, info.Duration);

sample_start_idx = max(1, floor(segment_start * info.SampleRate) + 1);
sample_end_idx = min(info.TotalSamples, ceil(segment_end * info.SampleRate));

[~, base_name, ~] = fileparts(audio_file);

segment = struct();
segment.id = string(sprintf('%s_ann_%04d', base_name, segment_index));
segment.audio_file = string(audio_file);
segment.label_file = string(label_file);
segment.label_text = string(label_entry.label_text);
segment.t_start_sec = label_entry.start_sec;
segment.t_end_sec = label_entry.end_sec;
segment.t_center_sec = center_sec;
segment.pad_left_sec = pad_left_sec;
segment.pad_right_sec = pad_right_sec;
segment.segment_start_sec = segment_start;
segment.segment_end_sec = segment_end;
segment.sample_start_idx = sample_start_idx;
segment.sample_end_idx = sample_end_idx;
segment.sample_rate = info.SampleRate;
segment.num_samples = sample_end_idx - sample_start_idx + 1;
segment.audio = [];
end
