function tests = test_binning_quantile
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testReturnsCompactIntegerBinMatrix(testCase)
dbMatrix = [1 2 3 4; 4 3 2 1];
[binMatrix, binEdges, binningMeta] = binning_quantile(dbMatrix, 2);

verifyTrue(testCase, isinteger(binMatrix));
verifySize(testCase, binMatrix, size(dbMatrix));
verifyEqual(testCase, binningMeta.n_bins, 2);
verifyEqual(testCase, numel(binEdges), 2);
verifyEqual(testCase, min(binMatrix, [], 'all'), cast(0, class(binMatrix)));
end
