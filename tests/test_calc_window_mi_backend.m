function tests = test_calc_window_mi_backend
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testFallsBackToMatlabWhenRequested(testCase)
[binMatrix, windowStartFrame, miConstants, permCache] = buildFixture();

[miWindow, shiftStats, backendUsed] = calc_window_mi_backend( ...
    binMatrix, windowStartFrame, miConstants, permCache, "matlab");

verifyEqual(testCase, backendUsed, "matlab");
verifySize(testCase, miWindow, [size(binMatrix, 1), miConstants.n_delays]);
verifyEqual(testCase, shiftStats.count, permCache.n_perms);
verifySize(testCase, shiftStats.mean, [size(binMatrix, 1), miConstants.n_delays]);
verifySize(testCase, shiftStats.median, [size(binMatrix, 1), miConstants.n_delays]);
verifySize(testCase, shiftStats.std, [size(binMatrix, 1), miConstants.n_delays]);
end

function testAutoBackendMatchesMatlab(testCase)
[binMatrix, windowStartFrame, miConstants, permCache] = buildFixture();

[miMatlab, shiftMatlab] = calc_window_mi_matlab( ...
    binMatrix, windowStartFrame, miConstants, permCache);
[miAuto, shiftAuto, backendUsed] = calc_window_mi_backend( ...
    binMatrix, windowStartFrame, miConstants, permCache, "auto");

verifyTrue(testCase, any(strcmp(backendUsed, ["matlab", "mex"])));
verifyEqual(testCase, miAuto, miMatlab, 'AbsTol', 1e-12);
verifyEqual(testCase, shiftAuto.count, shiftMatlab.count);
verifyEqual(testCase, shiftAuto.mean, shiftMatlab.mean, 'AbsTol', 1e-12);
verifyEqual(testCase, shiftAuto.median, shiftMatlab.median, 'AbsTol', 1e-12);
verifyEqual(testCase, shiftAuto.std, shiftMatlab.std, 'AbsTol', 1e-12);
end

function [binMatrix, windowStartFrame, miConstants, permCache] = buildFixture()
binMatrix = uint8([
    0 1 1 2 0 1 2 2 1 0;
    1 0 2 2 1 0 1 2 0 1;
    2 2 1 0 1 1 0 0 2 2
]);

windowStartFrame = int32(3);
dtFrames = int32(-1:1);
windowDurFrames = int32(4);

miConstants = struct();
miConstants.n_bins = 3;
miConstants.window_dur_frames = windowDurFrames;
miConstants.n_delays = numel(dtFrames);
miConstants.hist_size = int32(miConstants.n_bins * miConstants.n_bins);
miConstants.delay_offsets = int32(0:miConstants.n_delays-1) .* miConstants.hist_size;
miConstants.dt_frames_int32 = dtFrames(:).';
miConstants.phi_lut = zeros(double(windowDurFrames) + 1, 1);
counts = (1:double(windowDurFrames)).';
miConstants.phi_lut(2:end) = counts .* log(counts);
miConstants.log_window_dur = log(double(windowDurFrames));

permCache = struct();
permCache.reused = true;
permCache.n_perms = 2;
permCache.base_orders = int32([1 2 3 4; 4 3 2 1]);
permCache.shifted_linear_idx = zeros(double(windowDurFrames), numel(dtFrames), permCache.n_perms, 'int32');
permCache.shifted_linear_idx(:, :, 1) = int32([1 5 9; 2 6 10; 3 7 11; 4 8 12]);
permCache.shifted_linear_idx(:, :, 2) = int32([4 8 12; 3 7 11; 2 6 10; 1 5 9]);
end
