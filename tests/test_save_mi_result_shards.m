function tests = test_save_mi_result_shards
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testWritesTensorShardsAndManifest(testCase)
outDir = fullfile(tempdir, 'mi_result_shards_test');
if isfolder(outDir)
    rmdir(outDir, 's');
end
mkdir(outDir);
cleanupObj = onCleanup(@() cleanupDir(outDir));

segment = struct('id', "seg1", 'audio', [], 'audio_file', "a.wav");
fft_result = struct( ...
    'segment_id', "seg1", ...
    'sample_rate', 8000, ...
    'freq_hz', (1:3)', ...
    'time_sec', (1:10)', ...
    'spectrogram_db', rand(3, 10), ...
    'fft_params', struct('nfft', 2048));
binning_meta = struct('type', 'quantile', 'n_bins', 5);
mi_result = struct( ...
    'mi_values', rand(8, 9, 20), ...
    'dt_frames', 0:8, ...
    'dt_sec', 0:8, ...
    't0_frames', 1:20, ...
    'selected_freq_idx', 1:8, ...
    'selected_freq_hz', 1:8, ...
    'freq_band_hz', [1 8], ...
    'shift_mi', rand(8, 9, 3, 20), ...
    'run_params', struct('n_bins', 5), ...
    'provenance', struct('segment_id', "seg1"));
run_metadata = struct('max_shard_size_mb', 0.001, 'write_tensor_shards', true);

[matPath, payload] = save_mi_result( ...
    segment, fft_result, binning_meta, mi_result, outDir, run_metadata, true, 0.001, '-v7');

verifyTrue(testCase, isfile(matPath));
verifyTrue(testCase, isfield(payload.mi_result, 'tensor_shards'));
verifyGreaterThanOrEqual(testCase, numel(payload.mi_result.tensor_shards.mi_values), 2);
verifyEqual(testCase, numel(payload.mi_result.tensor_shards.shift_mi), 0);
verifyTrue(testCase, isfile(payload.mi_result.tensor_shards.mi_values(1).file_path));
verifyTrue(testCase, isfield(payload.mi_result, 'shift_stats'));
verifyTrue(testCase, isfield(payload.mi_result.shift_stats, 'mean'));
verifyTrue(testCase, isfield(payload.mi_result.shift_stats, 'median'));
verifyTrue(testCase, isfield(payload.mi_result.shift_stats, 'std'));
verifyFalse(testCase, isfield(payload.mi_result.shift_stats, 'variance'));
verifyTrue(testCase, isempty(payload.mi_result.shift_mi));
end

function cleanupDir(outDir)
if isfolder(outDir)
    rmdir(outDir, 's');
end
end
