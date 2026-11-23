function tests = test_all64_high_power_p1
%TEST_ALL64_HIGH_POWER_P1 Verify minimal-diff Profile 1 all-64 high-power TX driver.
% Run in an isolated MATLAB process because the SetUp script clears and
% populates base workspace variables required by vendor utilities.
tests = functiontests(localfunctions);
end

function testConstructedSequence(t)
root = fileparts(fileparts(mfilename('fullpath')));
scriptDir = fullfile(root, 'verasonics', 'curing_mode');
scriptPath = fullfile(scriptDir, 'SetUpP9_4TSICE_All64_HighPower_P1.m');
verifyTrue(t, isfile(scriptPath));

tmpDir = tempname;
mkdir(tmpDir);
mkdir(fullfile(tmpDir, 'MatFiles'));
oldDir = pwd;
oldPath = path;
cleanupEnv = onCleanup(@() restoreEnv(oldDir, oldPath, tmpDir)); %#ok<NASGU>

addpath( ...
    scriptDir, ...
    fullfile(root, 'VantageNXT-2.3.2-p2'), ...
    fullfile(root, 'VantageNXT-2.3.2-p2', 'Utilities'), ...
    fullfile(root, 'VantageNXT-2.3.2-p2', 'System'), ...
    fullfile(root, 'VantageNXT-2.3.2-p2', 'System', 'P_Files'), ...
    fullfile(root, 'VantageNXT-2.3.2-p2', 'vstoolbox'));
cd(tmpDir);

evalin('base', 'SetUpP9_4TSICE_All64_HighPower_P1;');

matPath = fullfile(tmpDir, 'MatFiles', 'SetUpP9_4TSICE_All64_HighPower_P1.mat');
verifyTrue(t, isfile(matPath));
s = load(matPath);

verifyEqual(t, s.Resource.Parameters.simulateMode, 1);
verifyEqual(t, s.Resource.Parameters.numTransmit, 128);
verifyEqual(t, s.Resource.Parameters.numRcvChannels, 128);
verifyEqual(t, mod(s.Resource.RcvBuffer(1).rowsPerFrame, 128), 0);
verifyEqual(t, s.Resource.RcvBuffer(1).numFrames, 1);

verifyEqual(t, s.Trans.numelements, 64);
verifyEqual(t, s.Trans.maxHighVoltage, 35);
verifyEqual(t, s.Trans.id, -1);
verifyEqual(t, s.Trans.impedance, 50);

verifyEqual(t, s.TPC(1).maxHighVoltage, 35);
verifyEqual(t, s.TPC(1).hv, 1.6, 'AbsTol', 1e-12);

verifyEqual(t, s.TW.type, 'parametric');
verifyEqual(t, s.TW.Parameters, [6, 1.0, 40, 1]);
verifyLessThan(t, s.TW.Parameters(3), 50);

if exist('computeTWWaveform', 'file') && exist('com.vsv.hal.Vantage', 'class') == 8
    [~, ~, ~, rc, twOut] = computeTWWaveform(s.TW);
    verifyEqual(t, rc, 0);
    verifyEqual(t, twOut.sysExtendBL, 0);
    verifyGreaterThanOrEqual(t, twOut.fluxHVlimit, 35);
else
    fprintf('[test_all64_high_power_p1] Skipped computeTWWaveform: Vantage NXT Java HAL (com.vsv.hal.Vantage) is not activated in this MATLAB session.\n');
end

verifyEqual(t, s.TX.Apod, ones(1, 64));
verifyEqual(t, s.TX.focus, 20 / (1.54 / s.Trans.frequency), 'AbsTol', 1e-12);
verifyEqual(t, s.TX.Steer, [0, 0]);
dist = sqrt(s.Trans.ElementPos(:, 1)'.^2 + s.TX.focus^2);
verifyEqual(t, s.TX.Delay, max(dist) - dist, 'AbsTol', 1e-10);

verifyTrue(t, isfield(s, 'PData') && isfield(s, 'TGC') && isfield(s, 'Receive'));
verifyEqual(t, numel(s.Receive), 1);
verifyEqual(t, s.Receive.callMediaFunc, 0);
verifyFalse(t, any(isfield(s, {'Recon', 'ReconInfo', 'Process', 'Media', 'UI'})));

verifyEqual(t, numel(s.Event), 501);
verifyEqual(t, sum([s.Event.tx] == 1), 500);
verifyTrue(t, all([s.Event.rcv] == 0 & [s.Event.recon] == 0 & [s.Event.process] == 0));
verifyEqual(t, s.Event(500).seqControl, 0);
verifyEqual(t, s.SeqControl(s.Event(501).seqControl).command, 'stop');
verifyEqual(t, s.SeqControl(1).command, 'timeToNextAcq');
verifyEqual(t, s.SeqControl(1).argument, 600);
verifyFalse(t, any(ismember({s.SeqControl.command}, {'jump', 'transferToHost'})));
end

function restoreEnv(oldDir, oldPath, tmpDir)
try
    cd(oldDir);
catch
end
try
    path(oldPath);
catch
end
try
    if isfolder(tmpDir)
        rmdir(tmpDir, 's');
    end
catch
end
end
