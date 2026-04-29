function plot_segment_preview(segment, fft_result, output_path)
%PLOT_SEGMENT_PREVIEW Быстрый preview сегмента.

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1000 420]);
t = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(t, 1);
plot(ax1, fft_result.waveform_time_sec, fft_result.waveform, 'Color', [0.1 0.1 0.1], 'LineWidth', 0.7);
grid(ax1, 'on');
xlabel(ax1, 'Время, с');
ylabel(ax1, 'Амплитуда');
title(ax1, sprintf('Waveform | %s', segment.id), 'Interpreter', 'none');

ax2 = nexttile(t, 2);
imagesc(ax2, fft_result.time_sec, fft_result.freq_hz, fft_result.spectrogram_db);
axis(ax2, 'xy');
colormap(ax2, parula);
colorbar(ax2);
xlabel(ax2, 'Время, с');
ylabel(ax2, 'Частота, Гц');
title(ax2, 'Спектрограмма, дБ');

export_figure_standard(fig, output_path);
close(fig);
end
