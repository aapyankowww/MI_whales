function [clamped_start, clamped_end] = clamp_interval(start_value, end_value, min_value, max_value)
%CLAMP_INTERVAL Ограничивает интервал доступными границами, сохраняя длину если возможно.

if end_value < start_value
    error('end_value должен быть не меньше start_value');
end

requested_duration = end_value - start_value;
available_duration = max_value - min_value;

if requested_duration >= available_duration
    clamped_start = min_value;
    clamped_end = max_value;
    return;
end

clamped_start = max(min_value, start_value);
clamped_end = clamped_start + requested_duration;

if clamped_end > max_value
    clamped_end = max_value;
    clamped_start = clamped_end - requested_duration;
end
end
