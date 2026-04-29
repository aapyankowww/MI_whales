function tests = test_make_plain_segments
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testSplitsAudioIntoSequentialSegments(testCase)
audioPath = fullfile(tempdir, 'plain_segments_test.wav');
fs = 1000;
x = 0.1 * randn(fs * 7, 1);
audiowrite(audioPath, x, fs);
cleanupObj = onCleanup(@() cleanupAudio(audioPath));

segments = make_plain_segments(audioPath, 3, 0);

verifyEqual(testCase, numel(segments), 3);
verifyEqual(testCase, segments(1).segment_start_sec, 0, 'AbsTol', 1e-9);
verifyEqual(testCase, segments(1).segment_end_sec, 3, 'AbsTol', 1e-9);
verifyEqual(testCase, segments(2).segment_start_sec, 3, 'AbsTol', 1e-9);
verifyEqual(testCase, segments(3).segment_end_sec, 7, 'AbsTol', 1e-9);
end

function cleanupAudio(audioPath)
if exist(audioPath, 'file')
    delete(audioPath);
end
end
