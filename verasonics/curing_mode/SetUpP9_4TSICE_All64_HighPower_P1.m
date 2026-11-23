% Minimal-diff all-64-element high-power TX adaptation of
% VantageNXT-2.3.2-p2/XJD/SetUpP9_4TSICE_FlashAngles.m.
% Uses TPC Profile 1 (<25 cycles, sysExtendBL=0) because systemInfo.txt
% (TMWS0204) lists no Extended Transmit or HIFU license.
% Probe ratings, actual acoustic output, thermal rise, and curing remain unknown.
% Offline construction only: simulateMode=1 and VSX is disabled.

clear all

P.startDepth = 0;
P.endDepth = 400;     % Acquisition depth in wavelengths
P.focusMm = 20;       % assumed target distance [mm]; 20 mm research target
P.steerDeg = 0;       % assumed azimuth steer [deg] in x-z plane
P.txFreqMHz = 6;      % existing_code_unverified transmit frequency [MHz]
P.halfCycleDuty = 1.0;% assumed B=1.0 max fundamental output (vs 0.67 imaging)
P.txCycles = 20;      % assumed <25 cycles (sysExtendBL=0 for Profile 1)
P.priUs = 600;        % assumed PRI [us] (~7.9-8.3 W avg into assumed 50 ohm at 35 V)
P.numPulses = 500;    % assumed finite pulse count (0.30 s burst train before stop)

% Specify system parameters.
Resource.Parameters.numTransmit = 128;  % number of transmit channels.
Resource.Parameters.numRcvChannels = 128;  % number of receive channels.
Resource.Parameters.speedOfSound = 1540;
Resource.Parameters.speedCorrectionFactor = 1.0;
Resource.Parameters.verbose = 2;
Resource.Parameters.initializeOnly = 0;
Resource.Parameters.simulateMode = 1; % Offline default; set 0 only after bench checks.

% Specify Trans structure array.
Trans.name = 'P9-4ULts';
Trans.units = 'wavelengths'; % required in Gen3 to prevent default to mm units
Trans = computeTrans(Trans);
Trans.maxHighVoltage = 35;  % existing_code_unverified software cap; probe rating unknown.
Trans.id = -1;

% Explicit TPC Profile 1 limits (no Extended Transmit / HIFU license in systemInfo.txt).
TPC(1).maxHighVoltage = Trans.maxHighVoltage;
TPC(1).hv = 1.6; % Safe startup voltage; ramp manually in VSX only after bench checks.

P.theta = -pi/4;
P.rayDelta = 2*(-P.theta);
P.aperture = 64*Trans.spacing; % P.aperture in wavelengths
P.radius = (P.aperture/2)/tan(-P.theta); % dist. to virt. apex

% Minimal PData retained for VSX loader compatibility (no imaging/recon events run).
PData(1).PDelta = [Trans.spacing, 0, 0.5];
PData(1).Size(1) = 10 + ceil((P.endDepth-P.startDepth)/PData(1).PDelta(3));
PData(1).Size(2) = 10 + ceil(2*(P.endDepth + P.radius)*sin(-P.theta)/PData(1).PDelta(1));
PData(1).Size(3) = 1;
PData(1).Origin = [-(PData(1).Size(2)/2)*PData(1).PDelta(1),0,P.startDepth];
PData(1).Region = struct(...
            'Shape',struct('Name','SectorFT', ...
            'Position',[0,0,0], ...
            'z',P.startDepth, ...
            'r',P.radius+P.endDepth, ...
            'angle',P.rayDelta, ...
            'steer',0));
PData(1).Region = computeRegions(PData(1));

% Minimal 1-frame RcvBuffer retained for VSX loader compatibility (4096 = 32*128).
Resource.RcvBuffer(1).datatype = 'int16';
Resource.RcvBuffer(1).rowsPerFrame = 4096;
Resource.RcvBuffer(1).colsPerFrame = Resource.Parameters.numRcvChannels;
Resource.RcvBuffer(1).numFrames = 1;

% Specify TW structure array (<25 cycles keeps sysExtendBL=0 on TPC Profile 1).
TW.type = 'parametric';
TW.Parameters = [P.txFreqMHz, P.halfCycleDuty, 2*P.txCycles, 1];

% Specify TX structure array (all 64 elements focused at P.focusMm, steered by P.steerDeg).
TX = struct('waveform', 1, ...
            'Origin', [0.0,0.0,0.0], ...
            'focus', P.focusMm/(Resource.Parameters.speedOfSound/1000/Trans.frequency), ...
            'Steer', [P.steerDeg*pi/180,0.0], ...
            'Apod', ones(1,64), ...
            'Delay', zeros(1,64));
TX.Delay = computeTXDelays(TX);

% Minimal unused Receive and TGC retained for VSX loader compatibility (never scheduled).
maxAcqLength = ceil(sqrt(P.aperture^2 + P.endDepth^2 - 2*P.aperture*P.endDepth*cos(P.theta-pi/2)) - P.startDepth);
wlsPer128 = 128/(4*2); % wavelengths in 128 samples for 4 samplesPerWave
Receive = struct('Apod', ones(1,64), ...
                 'startDepth', P.startDepth, ...
                 'endDepth', P.startDepth + wlsPer128*ceil(maxAcqLength/wlsPer128), ...
                 'TGC', 1, ...
                 'bufnum', 1, ...
                 'framenum', 1, ...
                 'acqNum', 1, ...
                 'sampleMode', 'NS200BW', ...
                 'demodFrequency', 12, ...
                 'mode', 0, ...
                 'callMediaFunc', 0);

TGC.CntrlPts = [0,431,450,603,637,749,921,944];
TGC.rangeMax = P.endDepth;
TGC.Waveform = computeTGCWaveform(TGC);

% Specify SeqControl and finite TX-only Event sequence (no Receive, DMA, Recon, or jump).
SeqControl(1).command = 'timeToNextAcq';
SeqControl(1).argument = P.priUs;
SeqControl(2).command = 'stop';
SeqControl(2).argument = [];

Event = repmat(struct('info', 'All-64 high-power TX', ...
                      'tx', 1, ...
                      'rcv', 0, ...
                      'recon', 0, ...
                      'process', 0, ...
                      'seqControl', 1), 1, P.numPulses + 1);
Event(P.numPulses).seqControl = 0;
Event(P.numPulses + 1) = struct('info', 'stop', ...
                                'tx', 0, ...
                                'rcv', 0, ...
                                'recon', 0, ...
                                'process', 0, ...
                                'seqControl', 2);

% Save all the structures to a .mat file.
filename = 'MatFiles/SetUpP9_4TSICE_All64_HighPower_P1';
save(filename);
% VSX; % Intentionally disabled; run VSX manually after parameter review.
return
