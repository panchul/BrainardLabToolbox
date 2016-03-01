function params = runModulationTrialSequencePupillometryNulledOnLine(exp)

    clc
    % Setup basic parameters for the experiment
    [params, block] = initParamsAndGenerateBlock(exp);

    %% Create the OneLight object.
    % This makes sure we are talking to OneLight.

    ol = OneLight;

    % Make sure our input and output pattern buffers are setup right.
    ol.InputPatternBuffer = 0;
    ol.OutputPatternBuffer = 0;

    fprintf('\n* Creating keyboard listener\n');
    mglListener('init');

    %% Calibration mode
    % The calibration mode exists to allow for a calibration of the x-y
    % positions of the eye tracker. This is currently not used, but an
    % appropriate routine to communicate with the VSG Winbox is implemented
    % below.
    VSGCALLIBRATE = false;

    % OLVSGSendCalibrateTarget tells the other computer to start the EyeTracking
    % routine, the one that makes sure the subject is looking at the target
    % throughout the experiment/run.  OLVSGSendCalibrateTarget tells the Windows
    % machine when to start recording.  This internal function also creates the
    % GUI for the experimenter so that the position can be selected.
    if VSGCALLIBRATE
        OLVSGSendCalibrateTarget();
    end

    % Run the trial loop.
    params = trialLoop(params, block, exp);

    % Toss the OLCache and OneLight objects because they are really only
    % ephemeral.
    params = rmfield(params, {'olCache'});
end

function params = trialLoop(params, block, exp)

    % Create the OneLight object.
    % This makes sure we are talking to OneLight.
    ol = OneLight;
        
    % Initialize a data structure to be used to obtain the data
    dataStruct = struct('diameter', -1, ...
        'time', -1, ...
        'time_inter', -1, ...
        'average_diameter', -1, ...
        'ratioInterupt', -1);

    % Determine the number of trials in this block and create a data struct of
    % that size
    dataStruct = repmat(dataStruct, params.nTrials, 1);
    offline = params.VSGOfflineMode;
        
    
    
    % === NEW ====== Instantiate a OLVSGcommunicator object ==================
    % OLVSGcommunicator will manage the UDP connection between the mac and the windows 
    % machine so that we can measure and monitor pupil size.
    OLVSG = OLVSGcommunicator( ...
            'signature', 'MacSide', ...              % a label indicating the host, used to for user-feedback
              'localIP', params.macHostIP, ...    % required: the IP of this computer
             'remoteIP', params.winHostIP, ...    % required: the IP of the computer we want to conenct to
              'udpPort', params.udpPort, ...      % optional, with default value: 2007
            'verbosity', 'min' ...                   % optional, with default value: 'normal', and possible values: {'min', 'normal', 'max'},
            );
    
    fprintf('\n<strong>%s</strong>; Hit enter when the windowsClient is up and running.\n', mfilename);
    pause;
    
    % Wake the Windows machine up
    OLVSG.sendParamValue({OLVSG.WAIT_STATUS, 'Wake Up'}, 'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'sending wake up message');
    
    % ==== NEW ===  Send param values =====================================
    OLVSG.sendParamValue({OLVSG.PROTOCOL_NAME,       params.protocolName},        'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'sending protocol name');
    OLVSG.sendParamValue({OLVSG.OBSERVER_ID,         params.obsID},               'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'sending observer ID');
    OLVSG.sendParamValue({OLVSG.OBSERVER_ID_AND_RUN, params.obsIDandRun},         'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'sending observer ID and run');
    OLVSG.sendParamValue({OLVSG.NUMBER_OF_TRIALS,    params.nTrials},             'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'sending number of trials');
    OLVSG.sendParamValue({OLVSG.STARTING_TRIAL_NO,   params.whichTrialToStartAt}, 'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'sending which trial to start at');
    OLVSG.sendParamValue({OLVSG.OFFLINE,             params.VSGOfflineMode},      'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'sending VSGOfflineMode');

    % Set the background to the 'idle' background appropriate for this
    % trial.
    fprintf('- Setting mirrors to background\n');
    ol.setMirrors(block(1).data.startsBG',  block(1).data.stopsBG'); % Use first trial

    events = struct();
        
    % UP TO HERE
   
    
    % Iterate over trials
    for trial = params.whichTrialToStartAt:params.nTrials
        
        fprintf('* Start trial %i/%i - %s, %.2f Hz.\n', trial, params.nTrials, block(trial).direction, block(trial).carrierFrequencyHz);
        system(['say Trial ' num2str(trial)  ' of ' num2str(params.nTrials)]);

        ol.setMirrors(block(1).data.startsBG',  block(1).data.stopsBG'); % Use first trial
  
        
        % Check the communication betwen Mac host and Win VET
        % Set some flags that are checked done below.
        readyToResume = false;
        isBeingTracked = false;
        params.run = false;

        % Play a tone to mark the beginning of the oncoming trial
        % Set up sounds
        fs = 20000;
        durSecs = 0.1;
        t = linspace(0, durSecs, durSecs*fs);
        yStart = [sin(880*2*pi*t)];
        yStop = [sin(440*2*pi*t)];

        
        % DEBUG
        %params.run = true; abort = false;
            
        % Check the tracking function of VET system
        while (params.run == false)
            sound(yStop, fs);  
            
            % Check whether the user is good to resume
            [readyToResume, abort] = OLVSGCheckResume(readyToResume, params, block(1).data.startsBG', block(1).data.stopsBG');
            
            % Send message that user is ready
            % ==== NEW ===  Send user ready status ========================
            OLVSG.sendParamValue({OLVSG.USER_READY_STATUS, 'user ready to move on'}, ...
                'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'User input acquired');
            % =============================================================
            
    
            % Wait to receive either a continue or an abort message
            % === NEW ====== Wait for ever to receive the userReady status ==================
            continueCheck = OLVSG.receiveParamValue(OLVSG.USER_READY_STATUS,  ...
                'timeOutSecs', 2.0, 'consoleMessage', 'Continue checking ?');
            % === NEW ====== Wait for ever to receive the userReady status ==================
            

            if strcmp(continueCheck, 'abort');
               abort = true;
            elseif strcmp(continueCheck, 'continue');
                % Let's make sure that the eye is being tracked
                isBeingTracked = OLVSGEyeTrackerCheck(OLVSG);
            else
                error('Unknown continueCheck value: ''%s''\n', continueCheck);
            end
                
            
            % When we are in in OFFLINE mode, we need to send over the
            % direction to the VSG computer so that it knows how to name
            % files
            %if (offline == true)
            %    reply = OLVSGSendDirection(params, trial);
            %    fprintf('%s',reply);
            %    isBeingTracked = true;
            %end

            if (abort == true)
                % If not, we break out.
                pause(5);
                system('say Could not track.');
                break;
            end                

            % If we have to redo the tracking, play a tone
            if (isBeingTracked == false)
                sound(yStop, fs);
            end

            % Here we establish where we are ready to go
            if (readyToResume == true && isBeingTracked == true)
                params.run = true;
            end
        end
            
        % Abort if true
        if (abort == true)
            break;
        end
            

        
        % Send the 'start' signal. Note that this will remain in the queue over at the VSG box.
        % reply = OLVSGSendEyeTrackingCommand;
        
        % ==== NEW ===  Send the 'startTracking' command ================================
        OLVSG.sendParamValue({OLVSG.EYE_TRACKER_STATUS, 'startTracking'}, ...
            'timeOutSecs', 5, 'maxAttemptsNum', 3, ...
            'consoleMessage', 'Sending request to start tracking');
        % =====================================================================
        
        
        
        
        sound(yStart, fs);
        if trial == 1 && params.skipPupilRecordingFirstTrial
            % If we're in the first trial, we stop recording
            % immediately and just show the background. That way, all
            % the things below still check out.

            % We stop recording.
%             reply = OLVSGStopPupilRecording(OLVSG);
%             fprintf('%s', reply);

            % ==== NEW ===  Send the 'stopTracking' command and wait for the trial outcome ====
            trialOutcome = OLVSG.sendParamValueAndWaitForResponse(...
                {OLVSG.EYE_TRACKER_STATUS, 'stopTracking'}, ...
                {OLVSG.TRIAL_OUTCOME}, ...                             % expected response label
                'timeOutSecs', 5, 'maxAttemptsNum', 3, ...
                'consoleMessage', 'Sending request to stop tracking');
            fprintf('%s', trialOutcome);
            % ==== NEW ===  Send the 'stopTracking' command and wait for the trial outcome ====
               
             
            
            % Launch into OLPDFlickerSettings.
            events(trial).tTrialStart = mglGetSecs;
            [~, events(trial).t] = ModulationTrialSequenceFlickerStartsStops(trial, params.timeStep, 1);
            events(trial).tTrialEnd = mglGetSecs;
          
        else

            % Launch into OLPDFlickerSettings.
            events(trial).tTrialStart = mglGetSecs;
            [~, events(trial).t] = ModulationTrialSequenceFlickerStartsStops(trial, params.timeStep, 1);
                events(trial).tTrialEnd = mglGetSecs;

            
            % We stop recording.
            % reply = OLVSGStopPupilRecording(OLVSG);
            
            % ==== NEW ===  Send the 'stopTracking' command and wait for the trial outcome ====
            trialOutcome = OLVSG.sendParamValueAndWaitForResponse(...
                {OLVSG.EYE_TRACKER_STATUS, 'stopTracking'}, ...
                {OLVSG.TRIAL_OUTCOME}, ...                             % expected response label
                'timeOutSecs', 5, 'maxAttemptsNum', 3, ...
                'consoleMessage', 'Sending request to stop tracking');
            fprintf('%s', trialOutcome);
            % ==== NEW ===  Send the 'stopTracking' command and wait for the trial outcome ====
        end
            
        
        % Save the data structure
        if (offline == false)
            % Get the data
            
            [time, diameter, good_counter, interruption_counter, time_inter] = ...
                OLVSGTransferData(OLVSG,trial, params, block(1).data.startsBG', block(1).data.stopsBG');

            
            % Calculate Some statistics on how good the measuremnts were
            good_counter = good_counter - 1;
            interruption_counter = interruption_counter - 1;
            ratioInterupt = (interruption_counter/(interruption_counter+good_counter));
            average_diameter = mean(diameter)*ones(size(time));

            % Assign what we obtain to the data structure.
            dataStruct(trial).diameter = diameter;
            dataStruct(trial).time = time;
            dataStruct(trial).time_inter = time_inter;
            dataStruct(trial).average_diameter = average_diameter;
            dataStruct(trial).ratioInterupt = ratioInterupt;

        end
            

        if strcmp(block(trial).modulationMode, 'AM')
            dataStruct(trial).frequencyEnvelope = block(trial).envelopeFrequencyHz;
            dataStruct(trial).phaseEnvelope = block(trial).carrierPhaseDeg;
            dataStruct(trial).modulationMode = block(trial).modulationMode;
        end

        if strcmp(block(trial).modulationMode, 'BG')
            dataStruct(trial).frequencyEnvelope = 0;
            dataStruct(trial).phaseEnvelope = 0;
            dataStruct(trial).modulationMode = block(trial).modulationMode;
        end

        if strcmp(block(trial).modulationMode, 'FM')
            dataStruct(trial).frequencyEnvelope = 0;
            dataStruct(trial).phaseEnvelope = 0;
            dataStruct(trial).modulationMode = block(trial).modulationMode;
        end
        dataStruct(trial).modulationMode = block(trial).modulationMode;

        if (offline == true)
            dataStruct(trial).frequencyCarrier = block(trial).carrierFrequencyHz;
            dataStruct(trial).phaseCarrier = block(trial).carrierPhaseDeg;
            dataStruct(trial).direction = block(trial).direction;
            dataStruct(trial).contrastRelMax = block(trial).contrastRelMax;

            if ~isempty(strfind(block(trial).modulationMode, 'pulse'))
                dataStruct(trial).frequencyEnvelope = 0;
                dataStruct(trial).phaseEnvelope = 0;
                dataStruct(trial).modulationMode = block(trial).modulationMode;
                dataStruct(trial).phaseRandSec = block(trial).phaseRandSec;
                dataStruct(trial).stepTimeSec = block(trial).stepTimeSec;
                dataStruct(trial).preStepTimeSec = block(trial).preStepTimeSec;
            end
        end

        
        % And clear the variables to get ready for the trial.
        clear time;
        clear diameter;
        clear good_counter;
        clear interruption_counter;
        clear time_inter;
            
    end % for trial
        
    tBlockEnd = mglGetSecs;
        
    fprintf('- Done with block.\n');

    system('say End of Experiment');
    

    ListenChar(0);

    % Turn all mirrors off
    ol.setMirrors(block(1).data.startsBG',  block(1).data.stopsBG'); % Use first trialol.setAll(false);

    
    % Tack data that we want for later analysis onto params structure.  It then
    % gets passed back to the calling routine and saved in our standard place.
    params.dataStruct = dataStruct;
    
    OLVSG.shutDown();
end


function [time, diameter, good_counter, interruption_counter, time_inter] = OLVSGTransferData(OLVSG, i, params, starts, stopsBackgroundIdle)
        % [time, diameter, good_counter, interruption_counter, time_inter] = OLVSGTransferData(i, params, starts, stopsBackgroundIdle)
        % Get the data from the VSG box
        

        % Set the mirrors to the background
        ol = OneLight;
        ol.setMirrors(starts,stopsBackgroundIdle);

        
        % Initialize the data transfer

        %matlabUDP('send','begin transfer');
        % fprintf('OLVSGTransferData: Beginning transfer of data...\n');
        
        % ==== NEW ===  Send begin transfer request and wait for acknowledgment ========================
        OLVSG.sendParamValueAndWaitForResponse(...
            {OLVSG.DATA_TRANSFER_STATUS, 'begin transfer'}, ...             % transmitted 
            {OLVSG.DATA_TRANSFER_STATUS, 'begin transfer'}, ...             % response label and value expected to be received
            'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'Sending request to begin data transfer');
        % ==== NEW ===  Send begin transfer request and wait for acknowledgment ========================
            
        
        
        fprintf('OLVSGTransferData: proceeding with data transfer\n');
        good_counter = 0;
        
        % Clear and initialize some variables
        clear diameter;
        clear time;
        clear time_inter;
        interruption_counter = 0;
        diameter(1) = 0;
        time(1) = 0;
        time_inter(1) = 0;
        
        % Get the number of data points to be transferred
        % === NEW ====== Wait for ever to receive the userReady status ==================
        nDataPoints = OLVSG.receiveParamValue(OLVSG.DATA_TRANSFER_POINTS_NUM,  'timeOutSecs', 2.0);
        % === NEW ====== Wait for ever to receive the userReady status ==================
                
        fprintf('OLVSGTransferData: The number of data points is %d\n', nDataPoints);
            
        % Iterate over the data points
        for i = 1:nDataPoints
            
            %matlabUDP('send', ['transfering ' num2str(i)]);
            %firstSampleTimeStamp = OLVSGGetInput;
            
            % === NEW == Send request to trasfer data point i, and wait to receive that point ===
            firstSampleTimeStamp = OLVSG.sendParamValueAndWaitForResponse(...
                {OLVSG.DATA_TRANSFER_REQUEST_FOR_POINT, i}, ...
                {OLVSG.DATA_FOR_POINT}, ...
                'timeOutSecs', 2, ...
                'consoleMessage', sprintf('Sending request for data point %d and waiting for response', i) ...
            );
            % === NEW == Send request to trasfer data point i, and wait to receive that point ===]
        
            parsedline = allwords(firstSampleTimeStamp, ' ');
            diam = str2double(parsedline{1});
            ti = str2double(parsedline{2});
            isinterruption = str2double(parsedline{3});
            interrupttime = str2double(parsedline{4});
            if (isinterruption == 0)
                good_counter = good_counter+1;
                diameter(good_counter) = diam;
                time(good_counter) = ti;
            elseif (isinterruption == 1)
                interruption_counter = interruption_counter + 1;
                time_inter(interruption_counter) = interrupttime;
            end
        end
        
        fprintf('OLVSGTransferData: Data transfer %f complete.\n', i)
        
        %matlabUDP('send','end transfer');
        
        % ==== NEW ===  Send the end transfer request  ========================
        OLVSG.sendParamValue({OLVSG.DATA_TRANSFER_STATUS, 'end transfer'}, 'consoleMessage', 'Sending request to end data transfer');
        % ==== NEW ===  Send the end transfer request  ========================
end
    

function isBeingTracked = OLVSGEyeTrackerCheck(OLVSG)
    % isBeingTracked = OLVSGEyeTrackerCheck
    % This function makes sure that the EyeTracker is successfully tracking
    % the subject's eye.
    %
    % We want to get 5 good data points for 5 seconds
    timeCheck = 5;
    dataCheck = 5;
    
    % OLVSGClearMessageBuffer;
    OLVSG.flashQueue()
    
    WaitSecs(1);
    
    % matlabUDP('send','startEyeTrackerCheck');
    % ==== NEW ===  Send eye tracker status = startEyeTrackerCheck ========
    OLVSG.sendParamValue({OLVSG.EYE_TRACKER_STATUS, 'startEyeTrackerCheck'}, ...
        'timeOutSecs', 2.0, 'maxAttemptsNum', 1, 'consoleMessage', 'Start eye tracking check.');
    % ==== NEW ============================================================
 
    
    tStart = mglGetSecs;

    while (mglGetSecs-tStart <= timeCheck)
        % Collecting checking data
    end

    % numTrackedData = OLVSGGetInput;
    % === NEW ====== Retrieve the number of eye tracking data points ==================
    numTrackedData = OLVSG.receiveParamValue(OLVSG.EYE_TRACKER_DATA_POINTS_NUM,  ...
        'timeOutSecs', 2.0, 'consoleMessage', 'Waiting for eye tracker data');
    % === NEW ====== Retrieve the number of eye tracking data points ==================
  
    % Clear the buffer
    % OLVSGClearMessageBuffer;
    OLVSG.flashQueue();
    
    if (numTrackedData >= dataCheck)
        isBeingTracked = true;
        %matlabUDP('send', 'true');
        % ==== NEW ===  Send user ready status ================================
        OLVSG.sendParamValue({OLVSG.EYE_TRACKER_STATUS, 'isTracking'}, ...
            'timeOutSecs', 2, 'consoleMessage', 'Eye tracking check was successful.');
        % =====================================================================
    else
        isBeingTracked = false;
        %matlabUDP('send', 'false');
        % ==== NEW ===  Send user ready status ================================
        OLVSG.sendParamValue({OLVSG.EYE_TRACKER_STATUS, 'isNotTracking'}, ...
            'timeOutSecs', 2, 'consoleMessage', 'Eye tracking check failed');
        % =====================================================================
    end

    
end


function [readyToResume, abort] = OLVSGCheckResume(readyToResume, params, starts, stopsBackgroundIdle)
    % [readyToResume, abort] = OLVSGCheckResume(readyToResume, params, stopsBackgroundIdle, starts)
    % Checks whether suject is okay to resume with next trial.

    % We need to explicitly re-set the mirrors to the background to prevent
    % OneLight from blinking the mirrors to zero during the function call away
    % from the main routine
    
    ol = OneLight;
    ol.setMirrors(starts,stopsBackgroundIdle);

    
    fs = 20000;
    durSecs = 0.01;
    t = linspace(0, durSecs, durSecs*fs);
    yHint = [sin(880*2*pi*t)];


    % Suppress keypresses going to the Matlab window.
    ListenChar(2); 

    
    resume = false;
    % Flush our keyboard queue.
    fprintf('Waiting for a key press ...\n');
    mglGetKeyEvent;
    keyPress = [];
    
    while (resume == false)
        %fprintf('waiting for response.'); This started working after adding
        %the pause...keep in mind 4 future
        pause(.1);
        key = mglGetKeyEvent;
        % If a key was pressed, get the key and exit.
        if ~isempty(key)
            sound(yHint, fs);
            keyPress = key.charCode;
            if (strcmp(keyPress,'a'))
                abort = true;
                readyToResume = false;
                resume = true;
                fprintf('Aborted.\n');
            else
                readyToResume = true;
                abort = false;
                resume = true;
            end
        end
    end
end
    

function [params, block] = initParamsAndGenerateBlock(exp)
    % params = initParams(exp)
    % Initialize the parameters

    [~, tmp, suff] = fileparts(exp.configFileName);
    exp.configFileName = fullfile(exp.configFileDir, [tmp, suff]);

    % Load the config file for this condition.
    cfgFile = ConfigFile(exp.configFileName);

    % Convert all the ConfigFile parameters into simple struct values.
    params = convertToStruct(cfgFile);
    params.cacheDir = fullfile(exp.baseDir, 'cache');

    % Load the calibration file.
    cType = OLCalibrationTypes.(params.calibrationType);
    params.oneLightCal = LoadCalFile(cType.CalFileName);

    % Setup the cache.
    params.olCache = OLCache(params.cacheDir, params.oneLightCal);

    file_names = allwords(params.modulationFiles,',');
    for i = 1:length(file_names)
        % Create the cache file name.
        [~, params.cacheFileName{i}] = fileparts(file_names{i});
    end
    params.protocolName = exp.protocolList(exp.protocolIndex).dataDirectory;
    params.obsIDAndRun = exp.obsIDAndRun;
    params.obsID = exp.subject;
    
    fprintf('> Trial numbers in protocol file:\n');
    fprintf('   nTrials: %g\n', params.nTrials);
    fprintf('   theFrequencyIndices: %g\n', length(params.theFrequencyIndices));
    fprintf('   thePhaseIndices: %g\n', length(params.thePhaseIndices));
    fprintf('   theDirections: %g\n', length(params.theDirections));
    fprintf('   theContrastRelMaxIndices: %g\n', length(params.theContrastRelMaxIndices));
    fprintf('   trialDuration: %g\n\n', length(params.trialDuration));

    % Ask for the observer age
    params.observerAgeInYears = GetWithDefault('>>> Observer age', 32);

    % Ask if we want to skip pupil recording in the first trial
    params.skipPupilRecordingFirstTrial = false;

    %% Put together the trial order
    for i = 1:length(params.cacheFileName)
        % Construct the file name to load in age-specific file

        %modulationData{i} = LoadCalFile(params.cacheFileName{i}, [], [params.cacheDir '/modulations/']);
        [~, fileName, fileSuffix] = fileparts(params.cacheFileName{i});
        %params.cacheFileName{i} = [fileName '-' exp.subject fileSuffix];
        params.cacheFileName{i} = [fileName '-' num2str(params.observerAgeInYears) fileSuffix];
        try
            modulationData{i} = load(fullfile(params.cacheDir, 'modulations', params.cacheFileName{i}));
        catch
            error('ERROR: Cache file for observer with specific age or nulling ID could not be found');
        end
    end

    % Put together the trial order
    % Pre-initialize the blocks
    block = struct();
    block(params.nTrials).describe = '';

    % Debug
    %params.nTrials = 1;

    params.whichTrialToStartAt = GetWithDefault('Which trial to start at?', 1);

    for i = 1:params.nTrials
        fprintf('- Preconfiguring trial %i/%i...', i, params.nTrials);
        block(i).data = modulationData{params.theDirections(i)}.modulationObj.modulation(params.theFrequencyIndices(i), params.thePhaseIndices(i), params.theContrastRelMaxIndices(i));
        block(i).describe = modulationData{params.theDirections(i)}.modulationObj.describe;

        % Check if the 'attentionTask' flag is set. If it is, set up the task
        % (brief stimulus offset).
        %block(i).attentionTask.flag = params.attentionTask(i);
        block(i).modulationMode = block(i).data.modulationMode;
        if ~isempty(strfind(block(i).modulationMode, 'pulse')) && isempty(strfind(block(i).describe.params.preCacheFileFull, 'DoublePulse'))
            block(i).direction = block(i).data.direction;

            block(i).contrastRelMax = block(i).describe.theContrastRelMax(params.theContrastRelMaxIndices(i));
            block(i).carrierFrequencyHz = -1;
            block(i).carrierPhaseDeg = -1;
            block(i).phaseRandSec = block(i).data.phaseRandSec;
            block(i).stepTimeSec = block(i).data.stepTimeSec;
            block(i).preStepTimeSec = block(i).data.preStepTimeSec;
        elseif ~isempty(strfind(block(i).describe.params.preCacheFileFull, 'DoublePulse'))
            block(i).direction = block(i).data.direction;
            block(i).contrastRelMax = block(i).describe.params.contrastScalars2(params.theContrastRelMaxIndices(i));
            block(i).carrierFrequencyHz = -1;
            block(i).carrierPhaseDeg = -1;
            block(i).phaseRandSec = block(i).data.phaseRandSec;
            block(i).stepTimeSec = block(i).data.stepTimeSec;
            block(i).preStepTimeSec = block(i).data.preStepTimeSec;
        else
            block(i).direction = block(i).data.direction;
            block(i).carrierFrequencyHz = block(i).describe.theFrequenciesHz(params.theFrequencyIndices(i));
            block(i).carrierPhaseDeg = block(i).describe.thePhasesDeg(params.thePhaseIndices(i));
            block(i).contrastRelMax = block(i).describe.theContrastRelMax(params.theContrastRelMaxIndices(i));
        end

        if strcmp(block(i).modulationMode, 'AM')
            block(i).envelopeFrequencyHz = block(i).data.theEnvelopeFrequencyHz;
            block(i).envelopePhaseDeg = block(i).carrierPhaseDeg;
            block(i).carrierPhaseDeg = 0;
        end

        if strcmp(block(i).direction, 'Background')
            block(i).modulationMode = 'BG';
            block(i).envelopePhaseDeg = 0;
            block(i).envelopeFrequencyHz = 0;
        end


        % We pull out the background.
        block(i).data.startsBG = block(i).data.starts(1, :);
        block(i).data.stopsBG = block(i).data.stops(1, :);

        fprintf('Done\n');
    end

    % Get rid of modulationData struct
    clear modulationData;
    
end
    