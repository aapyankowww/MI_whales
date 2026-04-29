function segments = make_plain_segments(audio_file, segment_duration_sec, segment_overlap_sec)
%MAKE_PLAIN_SEGMENTS Нарезает файл на последовательные сегменты фиксированной длины.

info = audioinfo(audio_file);
duration_sec = info.Duration;
step_sec = segment_duration_sec - segment_overlap_sec;

if step_sec <= 0
    error('segment_duration_sec должен быть больше segment_overlap_sec');
end

[~, base_name, ~] = fileparts(audio_file);

if duration_sec <= segment_duration_sec
    starts = 0;
else
    starts = 0:step_sec:duration_sec;
end

segments = repmat(empty_plain_segment(), 0, 1);
segment_counter = 0;

for start_sec = starts
    if start_sec >= duration_sec
        continue;
    end

    end_sec = min(start_sec + segment_duration_sec, duration_sec);
    segment_counter = segment_counter + 1;

    sample_start_idx = max(1, floor(start_sec * info.SampleRate) + 1);
    sample_end_idx = min(info.TotalSamples, ceil(end_sec * info.SampleRate));

    segment = struct();
    segment.id = string(sprintf('%s_plain_%04d', base_name, segment_counter));
    segment.audio_file = string(audio_file);
    segment.label_file = "";
    segment.label_text = "";
    segment.t_start_sec = [];
    segment.t_end_sec = [];
    segment.t_center_sec = (start_sec + end_sec) / 2;
    segment.pad_left_sec = 0;
    segment.pad_right_sec = 0;
    segment.segment_start_sec = start_sec;
    segment.segment_end_sec = end_sec;
    segment.sample_start_idx = sample_start_idx;
    segment.sample_end_idx = sample_end_idx;
    segment.sample_rate = info.SampleRate;
    segment.num_samples = sample_end_idx - sample_start_idx + 1;
    segment.audio = [];

    segments(end + 1, 1) = segment; %#ok<AGROW>
    if end_sec >= duration_sec
        break;
    end
end
end

function segment = empty_plain_segment()
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
