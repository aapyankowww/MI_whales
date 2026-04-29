repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(repo_root);
addpath(genpath(fullfile(repo_root, 'src')));
input_dir = fullfile(repo_root, 'results', 'example_inputs_annotated');
label_dir = fullfile(input_dir, 'labels');
audio_dir = fullfile(input_dir, 'audio');
output_dir = fullfile(repo_root, 'results', 'example_annotated_output');

if ~isfolder(audio_dir)
    mkdir(audio_dir);
end
if ~isfolder(label_dir)
    mkdir(label_dir);
end

audio_path = fullfile(audio_dir, 'annotated_demo.wav');
label_path = fullfile(label_dir, 'annotated_demo.txt');

if ~isfile(audio_path)
    fs = 8000;
    t = (0:fs*10-1)' / fs;
    x = 0.03 * randn(size(t));
    x = x + 0.40 * sin(2*pi*700*t) .* (t > 2.0 & t < 2.5);
    x = x + 0.35 * sin(2*pi*1100*t) .* (t > 6.0 & t < 6.3);
    x = x / max(abs(x)) * 0.9;
    audiowrite(audio_path, x, fs);
end

if ~isfile(label_path)
    fid = fopen(label_path, 'w');
    fprintf(fid, '2.000\t2.500\tcall_a\n');
    fprintf(fid, '6.000\t6.300\tcall_b\n');
    fclose(fid);
end

summary = run_mi_pipeline_core( ...
    audio_dir, label_dir, output_dir, ...
    1.5, 1.5, ...
    30.0, 0.0, ...
    "single", 700, [600 800], ...
    "uniform", 4, ...
    0.20, 0.40, 2, ...
    true, 0.95);
disp(summary.output_dir);
