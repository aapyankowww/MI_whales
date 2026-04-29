function export_figure_standard(fig_handle, output_path)
%EXPORT_FIGURE_STANDARD Единая точка экспорта графиков.

out_dir = fileparts(output_path);
if ~isfolder(out_dir)
    mkdir(out_dir);
end

exportgraphics(fig_handle, output_path, 'Resolution', 200);
end
