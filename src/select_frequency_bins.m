function [selected_idx, selected_freq_hz, freq_band_hz, meta] = select_frequency_bins(freq_hz, frequency_mode, target_hz, range_hz)
%SELECT_FREQUENCY_BINS Выбирает один бин или диапазон частот.

mode = lower(string(frequency_mode));
meta = struct();

switch mode
    case "single"
        if target_hz < min(freq_hz) || target_hz > max(freq_hz)
            error('Запрошенная частота %.2f Гц вне диапазона FFT [%.2f, %.2f] Гц', ...
                target_hz, min(freq_hz), max(freq_hz));
        end
        [~, idx] = min(abs(freq_hz - target_hz));
        selected_idx = idx;
        selected_freq_hz = freq_hz(idx);
        freq_band_hz = [selected_freq_hz, selected_freq_hz];
        meta.mode = "single";
        meta.requested_hz = target_hz;
    case "band"
        range_hz = range_hz(:).';
        if numel(range_hz) ~= 2 || range_hz(2) < range_hz(1)
            error('range_hz должен быть в виде [f_low, f_high]');
        end
        fft_min_hz = min(freq_hz);
        fft_max_hz = max(freq_hz);
        clipped_range_hz = [max(range_hz(1), fft_min_hz), min(range_hz(2), fft_max_hz)];

        if clipped_range_hz(2) < clipped_range_hz(1)
            error('Запрошенный диапазон [%.2f, %.2f] Гц не пересекается с диапазоном FFT [%.2f, %.2f] Гц', ...
                range_hz(1), range_hz(2), fft_min_hz, fft_max_hz);
        end
        mask = freq_hz >= clipped_range_hz(1) & freq_hz <= clipped_range_hz(2);
        selected_idx = find(mask);
        if isempty(selected_idx)
            error('В указанном диапазоне [%g, %g] Гц нет FFT-бинов', range_hz(1), range_hz(2));
        end
        selected_freq_hz = freq_hz(selected_idx);
        freq_band_hz = [range_hz(1), range_hz(2)];
        meta.mode = "band";
        meta.requested_hz = range_hz;
        meta.actual_hz = clipped_range_hz;
    otherwise
        error('Неподдерживаемый режим выбора частоты: %s', string(frequency_mode));
end
end
