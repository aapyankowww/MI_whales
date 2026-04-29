repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'src')));
input_dir = fullfile(repo_root, 'results', 'example_inputs');
output_dir = fullfile(repo_root, 'results', 'example_plain_output');

if ~isfolder(input_dir)
    mkdir(input_dir);
end

audio_path = fullfile(input_dir, 'plain_demo.wav');
if ~isfile(audio_path)
    fs = 8000;
    t = (0:fs*12-1)' / fs;
    x = 0.25 * sin(2*pi*440*t) ...
      + 0.18 * sin(2*pi*880*t) .* (t > 3 & t < 8) ...
      + 0.05 * randn(size(t));
    x = x / max(abs(x)) * 0.9;
    audiowrite(audio_path, x, fs);
end

summary = run_mi_pipeline_core( ...
    audio_path, "", output_dir, ...
    0.0, 0.0, ...
    6.0, 0.0, ...
    "band", 0, [300 1200], ...
    "quantile", 4, ...
    0.25, 0.50, 2, ...
    true, 0.95);
disp(summary.output_dir);
