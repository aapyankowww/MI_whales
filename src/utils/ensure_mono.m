function x = ensure_mono(x)
%ENSURE_MONO Приводит аудио к одному каналу усреднением.

if size(x, 2) > 1
    x = mean(x, 2);
end
end
