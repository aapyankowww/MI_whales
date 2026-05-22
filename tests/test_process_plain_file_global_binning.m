function tests = test_process_plain_file_global_binning
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testSavesOneMatPerWindowAndUsesFileLevelBinning(testCase)
audioPath = fullfile(tempdir, 'plain_global_binning_test.wav');
outDir = fullfile(tempdir, 'plain_global_binning_test_out');

if isfolder(outDir)
    rmdir(outDir, 's');
end
mkdir(outDir);

fs = 8000;
t = (0:fs*8-1).' / fs;
x = 0.2 * sin(2*pi*400*t) ...
    + 0.1 * sin(2*pi*1200*t) .* (t >= 3 & t < 6) ...
    + 0.02 * randn(size(t));
audiowrite(audioPath, x, fs);

cleanupObj = onCleanup(@() cleanupArtifacts(audioPath, outDir)); %#ok<NASGU>

runMetadata = struct('plain_processing_mode', "file_global_binning");

summary = process_plain_file_global_binning( ...
    audioPath, outDir, ...
    "band", 0, [0 4000], ...
    "uniform", 4, ...
    0.5, 1.0, 2, ...
    true, '-v7.3', ...
    false, true, 8, '-v7.3', ...
    false, 0.95, runMetadata, false);

verifyEqual(testCase, summary.window_count, 6);
verifyEqual(testCase, numel(summary.window_results), summary.window_count);
verifyTrue(testCase, isfile(summary.file_result_path));
verifyTrue(testCase, all(isfile(string({summary.window_results.mat_path}))));

firstWindow = load(summary.window_results(1).mat_path);
verifyEqual(testCase, size(firstWindow.mi_window, 1), 512);
verifyEqual(testCase, size(firstWindow.mi_window, 2), numel(summary.dt_sec));
verifyEqual(testCase, firstWindow.window_meta.window_index, 1);
verifyEqual(testCase, firstWindow.window_meta.requested_window_start_sec, 1.0, 'AbsTol', 1e-12);
verifyEqual(testCase, firstWindow.window_meta.requested_window_end_sec, 2.0, 'AbsTol', 1e-12);
verifyGreaterThan(testCase, firstWindow.window_meta.fft_window_start_sec, 0.9);
verifyLessThan(testCase, firstWindow.window_meta.fft_window_start_sec, 1.1);
verifyFalse(testCase, isfield(firstWindow, 'shift_mi_window'));
verifyTrue(testCase, isfield(firstWindow, 'shift_stats'));
verifyTrue(testCase, isfield(firstWindow.shift_stats, 'mean'));
verifyTrue(testCase, isfield(firstWindow.shift_stats, 'median'));
verifyTrue(testCase, isfield(firstWindow.shift_stats, 'std'));
verifyFalse(testCase, isfield(firstWindow.shift_stats, 'variance'));
verifyEqual(testCase, firstWindow.shift_stats.count, 2);

fileResult = load(summary.file_result_path);
fullSegment = build_full_file_segment(audioPath);
fftResult = fft_calc(fullSegment);
[selectedIdx, ~, ~, ~] = select_frequency_bins(fftResult.freq_hz, "band", 0, [0 4000]);
[~, expectedEdges, ~] = binning_uniform(fftResult.spectrogram_db(selectedIdx, :), 4);

verifyEqual(testCase, fileResult.binning_meta.scope, "full_file");
verifyEqual(testCase, fileResult.binning_meta.bin_edges, expectedEdges, 'AbsTol', 1e-10);
verifyEqual(testCase, numel(fileResult.window_manifest), summary.window_count);
verifyEqual(testCase, fileResult.file_level_result.requested_window_start_sec(1), 1.0, 'AbsTol', 1e-12);
verifyEqual(testCase, fileResult.file_level_result.requested_window_end_sec(1), 2.0, 'AbsTol', 1e-12);
verifyTrue(testCase, isfield(fileResult.file_level_result, 'shift_window_stats'));
verifyTrue(testCase, isempty(fileResult.file_level_result.shift_mi));
verifyTrue(testCase, isempty(fileResult.file_level_result.shift_window_stats));
verifyGreaterThan(testCase, summary.timing.fft_pass1_sec, 0);
verifyGreaterThan(testCase, summary.timing.fft_pass2_sec, 0);
verifyGreaterThan(testCase, summary.timing.binning_sec, 0);
verifyGreaterThan(testCase, summary.timing.mi_windows_sec, 0);
verifyGreaterThan(testCase, fileResult.timing.window_save_sec, 0);
verifyGreaterThan(testCase, fileResult.timing.file_result_save_sec, 0);
verifyGreaterThan(testCase, fileResult.timing.total_sec, 0);
verifyEqual(testCase, summary.window_backend, "matlab");
end

function testWritesProgressTimingToConsole(testCase)
audioPath = fullfile(tempdir, 'plain_global_progress_test.wav');
outDir = fullfile(tempdir, 'plain_global_progress_test_out');

if isfolder(outDir)
    rmdir(outDir, 's');
end
mkdir(outDir);

fs = 8000;
t = (0:fs*4-1).' / fs;
x = 0.2 * sin(2*pi*600*t) + 0.02 * randn(size(t));
audiowrite(audioPath, x, fs);

cleanupObj = onCleanup(@() cleanupArtifacts(audioPath, outDir)); %#ok<NASGU>

cmd = [ ...
    "process_plain_file_global_binning(" ...
    "'" + strrep(audioPath, '\', '\\') + "', " ...
    "'" + strrep(outDir, '\', '\\') + "', " ...
    """band"", 0, [0 4000], " ...
    """uniform"", 4, " ...
    "0.25, 1.0, 0, " ...
    "true, '-v7.3', " ...
    "false, true, 8, '-v7.3', " ...
    "false, 0.95, struct('plain_processing_mode', ""file_global_binning""), false);" ...
    ];

consoleOutput = evalc(char(cmd));

verifySubstring(testCase, consoleOutput, 'FFT pass 1');
verifySubstring(testCase, consoleOutput, 'FFT pass 2');
verifySubstring(testCase, consoleOutput, 'Окно 1/');
verifySubstring(testCase, consoleOutput, 'Итого по файлу');
verifySubstring(testCase, consoleOutput, 't=[1.00, 2.00] c');
end

function cleanupArtifacts(audioPath, outDir)
if exist(audioPath, 'file')
    delete(audioPath);
end
if isfolder(outDir)
    rmdir(outDir, 's');
end
end
