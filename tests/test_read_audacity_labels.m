function tests = test_read_audacity_labels
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repoRoot, 'src')));
testCase.TestData.repoRoot = repoRoot;
end

function testParsesIntervalLabels(testCase)
tmpFile = fullfile(tempdir, 'audacity_labels_test.txt');
fid = fopen(tmpFile, 'w');
cleanupObj = onCleanup(@() cleanupFile(tmpFile));
fprintf(fid, '0.100\t0.400\tcall_a\n');
fprintf(fid, '1.250\t1.800\tcall_b\n');
fclose(fid);

labels = read_audacity_labels(tmpFile);

verifyEqual(testCase, numel(labels), 2);
verifyEqual(testCase, labels(1).start_sec, 0.1, 'AbsTol', 1e-9);
verifyEqual(testCase, labels(1).end_sec, 0.4, 'AbsTol', 1e-9);
verifyEqual(testCase, labels(1).label_text, "call_a");
verifyEqual(testCase, labels(2).label_text, "call_b");
end

function testParsesHeaderBasedLabels(testCase)
tmpFile = fullfile(tempdir, 'audacity_labels_header_test.txt');
fid = fopen(tmpFile, 'w');
cleanupObj = onCleanup(@() cleanupFile(tmpFile));
fprintf(fid, 'start\tstop\tcomment_text\n');
fprintf(fid, '0.500\t0.900\talpha\n');
fprintf(fid, '1.100\t1.600\tbeta\n');
fclose(fid);

labels = read_audacity_labels(tmpFile);

verifyEqual(testCase, numel(labels), 2);
verifyEqual(testCase, labels(1).start_sec, 0.5, 'AbsTol', 1e-9);
verifyEqual(testCase, labels(1).end_sec, 0.9, 'AbsTol', 1e-9);
verifyEqual(testCase, labels(1).label_text, "alpha");
verifyEqual(testCase, labels(2).label_text, "beta");
end

function cleanupFile(filePath)
if exist(filePath, 'file')
    delete(filePath);
end
end
