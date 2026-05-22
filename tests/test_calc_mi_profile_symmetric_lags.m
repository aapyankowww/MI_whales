function tests = test_calc_mi_profile_symmetric_lags
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testReturnsNegativeAndPositiveLags(testCase)
bin_matrix = int32(randi([0 3], 2, 30));
fft_result = struct( ...
    'time_sec', (0:29) * 0.5, ...
    'sample_rate', 8000, ...
    'fft_params', struct('window_samples', 8, 'overlap_samples', 4));
selected_freq_idx = [1 2];
selected_freq_hz = [100 200];
freq_band_hz = [100 200];
binning_meta = struct('type', 'uniform', 'n_bins', 4);
segment = struct('id', "sym_test");

mi_result = calc_mi_profile( ...
    bin_matrix, fft_result, ...
    selected_freq_idx, selected_freq_hz, freq_band_hz, ...
    1.0, 1.0, 0, ...
    binning_meta, segment);

verifyEqual(testCase, mi_result.dt_frames, -2:2);
verifyEqual(testCase, mi_result.dt_sec, (-2:2) * 0.5, 'AbsTol', 1e-12);
verifySize(testCase, mi_result.mi_values, [2 5 13]);
verifyEqual(testCase, mi_result.t0_frames(1), 3);
end
