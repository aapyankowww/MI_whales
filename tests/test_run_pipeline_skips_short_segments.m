function tests = test_run_pipeline_skips_short_segments
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
addpath(genpath(fullfile(repoRoot, 'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testContinuesWhenOneSegmentIsTooShort(testCase)
rootDir = fullfile(tempdir, 'mi_pipeline_skip_short_test');
audioDir = fullfile(rootDir, 'audio');
outDir = fullfile(rootDir, 'out');
if isfolder(rootDir)
    rmdir(rootDir, 's');
end
mkdir(audioDir);
cleanupObj = onCleanup(@() cleanupDir(rootDir));

fs = 8000;
tLong = (0:fs*25-1)' / fs;
xLong = 0.2 * sin(2*pi*300*tLong);
audiowrite(fullfile(audioDir, 'long.wav'), xLong, fs);

tShort = (0:fs*8-1)' / fs;
xShort = 0.2 * sin(2*pi*300*tShort);
audiowrite(fullfile(audioDir, 'short.wav'), xShort, fs);

summary = run_mi_pipeline_core( ...
    audioDir, "", outDir, ...
    0.0, 0.0, ...
    30.0, 0.0, ...
    "single", 300, [200 400], ...
    "uniform", 4, ...
    10.0, 1.0, 0, ...
    false, 0.95, ...
    true, 8, '-v7.3', ...
    "file_global_binning", true, false, '-v7.3', false);

statuses = string({summary.results.status});
verifyTrue(testCase, any(statuses == "ok"));
verifyTrue(testCase, any(statuses == "failed"));
end

function cleanupDir(rootDir)
if isfolder(rootDir)
    rmdir(rootDir, 's');
end
end
