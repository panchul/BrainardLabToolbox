function demoUDPcommunicator
    clc;
    
    % Define the communication exchange protocol
    step = 1;
    commProtocol{step} = struct(...
        'message', struct('label', 'test1', 'value', 1), ...
        'direction', 'manta -> ionean', ...
        'transmitTimeOut', 1, ...
        'receiveTimeOut', 1 ...
    );
    
    
    % Get computer info
    systemInfo = GetComputerInfo()
    
    %% Instantiate a UDPcommunicator object according to computer name
    % In this demo we have IPs for 2 computers: manta.psych.upenn.edu and ionean.psych.upenn.edu
    if (strfind(systemInfo.networkName, 'manta'))
        UDPobj = UDPcommunicator( ...
            'localIP',   '128.91.12.90', ...    % REQUIRED: the IP of manta.psych.upenn.edu (local host)
            'remoteIP',  '128.91.12.144', ...   % REQUIRED: the IP of ionean.psych.upenn.edu (remote host)
            'verbosity', 'normal', ...             % OPTIONAL, with default value: 'normal', and possible values: {'min', 'normal', 'max'},
            'useNativeUDP', false ...           % OPTIONAL, with default value: false (i.e., using the brainard lab matlabUDP mexfile)
        );
    elseif (strfind(systemInfo.networkName, 'ionean'))
        UDPobj = UDPcommunicator( ...
        'localIP',   '128.91.12.144', ...       % REQUIRED: the IP of ionean.psych.upenn.edu (local host)
        'remoteIP',  '128.91.12.90', ...        % REQUIRED: the IP of manta.psych.upenn.edu (remote host)
        'verbosity', 'normal', ...                 % OPTIONAL, with default value: 'normal', and possible values: {'min', 'normal', 'max'},
        'useNativeUDP', false ...               % OPTIONAL, with default value: false (i.e., using the brainard lab matlabUDP mexfile)
        );
    else
        error('No configuration for computer named ''%s''.', systemInfo.networkName);
    end

    %% Set up'manta' as the slave (listener) and 'ionean' as the master (emitter)
    % Trigger the communication
    triggerMessage = struct(...
        'label', 'GO !', ...
        'value', 'now' ...
        );
    
    if (strfind(systemInfo.networkName, 'manta'))
        % Wait for ever to receive the trigger message from the master
        receive(UDPobj, triggerMessage, Inf);
    else
        fprintf('Is ''%s'' running on the slave computer?. Hit enter if so.\n', mfilename); pause; clc;
        % Send trigger and wait for up to 4 seconds to receive acknowledgment
        transmit(UDPobj, triggerMessage, 4.0);
    end

    % Run the communication exchange protocol
    for commStep = 1:numel(commProtocol)
         communicate(UDPobj, systemInfo.networkName, commStep, commProtocol{communicationStep});
    end
        
    fprintf('\nAll done\n');
    UDPobj.shutDown();
end

function communicate(UDPobj, computerName, packetNo, communicationPacket)
    message = communicationPacket.message;
    direction = communicationPacket.direction;
    transmitTimeOut = communicationPacket.transmitTimeOut;
    receiveTimeOut = communicationPacket.receiveTimeOut;
    
    computerName
    strfind(direction, computerName)
    strfind(direction, '->')
    strfind(direction, '<-');

end

% Method that waits to receive a message
function receive(UDPobj, expectedMessage, receiverTimeOutSecs)  
    % Start listening
    messageReceived = UDPobj.waitForMessage(expectedMessage.label, ...
        'timeOutSecs', receiverTimeOutSecs...
        );
    if (~isempty(expectedMessage.value))
        % Assert that we received the expected message value
        assert(strcmp(messageReceived.msgValue,expectedMessage.value), 'Expected and received message values differ');
    end
end

% Method that transmits a message and waits for an ACK
function transmit(UDPobj, messageToTransmit, acknowledgmentTimeOutSecs)
    % Send the message
    status = UDPobj.sendMessage(messageToTransmit.label, messageToTransmit.value, ...
        'timeOutSecs', acknowledgmentTimeOutSecs, ...
        'maxAttemptsNum', 1 ...
    );
    assert(~strcmp(status,'TIMED_OUT_WAITING_FOR_ACKNOWLEDGMENT'), 'Timed out waiting for acknowledgment');
end
