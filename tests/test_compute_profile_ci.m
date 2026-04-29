function tests = test_compute_profile_ci
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testComputesMeanAndConfidenceBounds(testCase)
samples = [1 2 3; 2 3 4; 3 4 5];
stats = compute_profile_ci(samples, 0.95);

verifyEqual(testCase, stats.mean_profile, [2 3 4], 'AbsTol', 1e-12);
verifySize(testCase, stats.ci_lower, [1 3]);
verifySize(testCase, stats.ci_upper, [1 3]);
verifyLessThanOrEqual(testCase, stats.ci_lower, stats.mean_profile + 1e-12);
verifyGreaterThanOrEqual(testCase, stats.ci_upper, stats.mean_profile - 1e-12);
end
