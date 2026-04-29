function output_dir = default_output_dir(repo_root)
%DEFAULT_OUTPUT_DIR Возвращает стандартную папку вывода для запуска.

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
output_dir = fullfile(repo_root, 'results', ['run_' stamp]);
end
