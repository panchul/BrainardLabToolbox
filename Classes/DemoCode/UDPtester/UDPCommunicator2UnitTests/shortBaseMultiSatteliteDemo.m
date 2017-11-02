function shortBaseMultiSatteliteDemo

    %% Start fresh
    fprintf('\nClearing stuff\n');
    clear all;
    fprintf('\n\n');
    
    %% Define a 2-sattelite scheme
    baseHostName = 'manta';
    sattelite1HostName = 'ionean';
    sattelite2HostName = 'gka06';
    sattelite3HostName = 'monkfish';
    
    %% Define a 3-sattelite scheme
    hostNames       = {baseHostName,    sattelite1HostName,  sattelite2HostName,  sattelite3HostName};
    hostIPs         = {'128.91.12.90',  '128.91.12.144',     '128.91.12.160',     '128.91.12.161'};
    hostRoles       = {'base',          'sattelite',         'sattelite',         'sattelite'};
    
    %% Control what is printed on the command window
    beVerbose = false;
    displayPackets = true;
    
    %% Instantiate the UDPBaseSatteliteCommunicator object
    UDPobj = UDPBaseSatteliteCommunicator.instantiateObject(hostNames, hostIPs, hostRoles, beVerbose);
    
    
    %% Use 10 second time out for all comms
    timeOutSecs = 30;
    
    %% Make the packetSequences for the base
    if (contains(UDPobj.localHostName, baseHostName))
        satteliteNames = {...
            sattelite1HostName, ...
            sattelite2HostName, ...
            sattelite3HostName};
        satteliteChannelIDs = {...
            UDPobj.satteliteInfo(sattelite1HostName).satteliteChannelID, ...
            UDPobj.satteliteInfo(sattelite2HostName).satteliteChannelID, ...
            UDPobj.satteliteInfo(sattelite3HostName).satteliteChannelID, ...
            };
        packetSequence = designPacketSequenceForBase(baseHostName, ...
                satteliteNames,...
                satteliteChannelIDs, ...
                timeOutSecs);    
    end
    
    %% Make the packetSequences for the sattelite(s)
    if (contains(UDPobj.localHostName, sattelite3HostName))
        packetSequence = designPacketSequenceForSattelite3(baseHostName, ...
            sattelite3HostName, ...
            UDPobj.satteliteInfo(sattelite3HostName).satteliteChannelID, ...
            timeOutSecs);
    
    elseif (contains(UDPobj.localHostName, sattelite2HostName))
        packetSequence = designPacketSequenceForSattelite2(baseHostName, ...
            sattelite2HostName, ...
            UDPobj.satteliteInfo(sattelite2HostName).satteliteChannelID, ...
            timeOutSecs);
        
    elseif (contains(UDPobj.localHostName, sattelite1HostName))
        packetSequence = designPacketSequenceForSattelite1(baseHostName, ...
            sattelite1HostName, ...
            UDPobj.satteliteInfo(sattelite1HostName).satteliteChannelID, ...
            timeOutSecs);
    end
    
    %% Establish the base / multi-sattelite communication
    triggerMessage = 'Go!';
    allSattelitesAreAGOMessage = 'All Sattelites Are A GO!';
    UDPobj.initiateCommunication(hostRoles,  hostNames, triggerMessage, allSattelitesAreAGOMessage, 'beVerbose', beVerbose);
    
    %% Execute communication protocol
    for packetNo = 1:numel(packetSequence)
        [theMessageReceived, theCommunicationStatus, roundTipDelayMilliSecs] = ...
            UDPobj.communicate(packetNo, packetSequence{packetNo}, ...
                'beVerbose', beVerbose, ...
                'displayPackets', displayPackets...
             );
    end % packetNo
end

%
% DESIGN PACKET SEQUENCE FOR SATTELITE-1
%
function packetSequence = designPacketSequenceForSattelite1(baseHostName, satteliteHostName, satteliteChannelID, timeOutSecs)
    % Define the communication  packetSequence
    packetSequence = {};
    
    % Sattelite receiving from Base
    direction = sprintf('%s -> %s', baseHostName, satteliteHostName);
    expectedMessageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, satteliteHostName);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction, ...
        expectedMessageLabel, ...
        'timeOutSecs', timeOutSecs, ...                                             % Wait for this many secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...     % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite receiving from Base
    direction = sprintf('%s -> %s', baseHostName, satteliteHostName); 
    expectedMessageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, satteliteHostName);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID,...
        direction, ...
        expectedMessageLabel, ...
        'timeOutSecs', timeOutSecs, ...                                            % Wait for this many secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...           % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite sending to Base
    direction = sprintf('%s <- %s', baseHostName, satteliteHostName);
    messageLabel = sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT', satteliteHostName);
    messageData = struct('a', 12, 'b', [1 2 3; 4 5 6; 7 8 9]);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction, ...
        messageLabel, 'withData', messageData, ...
        'timeOutSecs', timeOutSecs, ...                                            % Allow this many secs to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite sending to Base 100 cosine coefficients
    for k = 1:100
        direction = sprintf('%s <- %s', baseHostName, satteliteHostName);
        messageLabel = sprintf('SATTELITE(%s)___SENDING_COS_COEFF', satteliteHostName);
        messageData = cos(2*pi*k/100);
        packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
            satteliteChannelID, ...
            direction, ...
            messageLabel, 'withData', messageData, ...
            'timeOutSecs', timeOutSecs, ...                                            % Allow this many secs to receive ACK (from remote host) that message was received 
            'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        );
    end
    
end

%
% DESIGN PACKET SEQUENCE FOR SATTELITE-2
%
function packetSequence = designPacketSequenceForSattelite2(baseHostName, satteliteHostName, satteliteChannelID, timeOutSecs)
    % Define the communication  packetSequence
    packetSequence = {};
    
    % Sattelite receiving from Base
    direction = sprintf('%s -> %s', baseHostName, satteliteHostName);
    expectedMessageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, satteliteHostName);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction, ...
        expectedMessageLabel, ...
        'timeOutSecs', timeOutSecs, ...                                             % Wait for this many secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...     % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite receiving from Base
    direction = sprintf('%s -> %s', baseHostName, satteliteHostName);
    expectedMessageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, satteliteHostName);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction, ...
        expectedMessageLabel, ...
        'timeOutSecs', timeOutSecs, ...                                                    % Wait for this many secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...           % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite sending to Base
    direction = sprintf('%s <- %s', baseHostName, satteliteHostName);
    messageLabel = sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT', satteliteHostName);
    messageData = struct('a', 12, 'b', [10 20; 30 40; 50 60; 70 80; 90 100]);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction,...
        messageLabel, 'withData', messageData, ...
        'timeOutSecs', timeOutSecs, ...                                    % Allow this many secs to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
   );

    % Sattelite sending to Base 100 sine coefficients
    for k = 1:100
        direction = sprintf('%s <- %s', baseHostName, satteliteHostName);
        messageLabel = sprintf('SATTELITE(%s)___SENDING_SIN_COEFF', satteliteHostName);
        messageData = sin(2*pi*k/100);
        packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
            satteliteChannelID, ...
            direction, ...
            messageLabel, 'withData', messageData, ...
            'timeOutSecs', timeOutSecs, ...                                            % Allow this many secs to receive ACK (from remote host) that message was received 
            'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        );
    end
    
end

%
% DESIGN PACKET SEQUENCE FOR SATTELITE-3
%
function packetSequence = designPacketSequenceForSattelite3(baseHostName, satteliteHostName, satteliteChannelID, timeOutSecs)
    % Define the communication  packetSequence
    packetSequence = {};
    
    % Sattelite receiving from Base
    direction = sprintf('%s -> %s', baseHostName, satteliteHostName);
    expectedMessageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, satteliteHostName);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction,...
        expectedMessageLabel, ...
        'timeOutSecs', timeOutSecs, ...                                             % Wait for timeOutSecsto receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...     % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite receiving from Base
    direction =  sprintf('%s -> %s', baseHostName, satteliteHostName);
    expectedMessageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, satteliteHostName);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction, ...
        expectedMessageLabel,...
        'timeOutSecs', timeOutSecs, ...                                            % Wait for timeOutSecs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...           % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite sending to Base
    direction = sprintf('%s <- %s', baseHostName, satteliteHostName);
    messageLabel = sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT', satteliteHostName);
    messageData = struct('a', 12, 'b', rand(5,5));
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction, ...
        messageLabel, 'withData', messageData, ...
        'timeOutSecs', timeOutSecs, ...                                    % Allow timeOutSecs  to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite sending to Base 100 radial coefficients
    for k = -49:50
        direction = sprintf('%s <- %s', baseHostName, satteliteHostName);
        messageLabel = sprintf('SATTELITE(%s)___SENDING_RADIAL_COEFF', satteliteHostName);
        messageData = k;
        packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
            satteliteChannelID, ...
            direction, ...
            messageLabel, 'withData', messageData, ...
            'timeOutSecs', timeOutSecs, ...                                            % Allow this many secs to receive ACK (from remote host) that message was received 
            'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        );
    end
    
end


%
% DESIGN PACKET SEQUENCE FOR BASE
%
function packetSequence = designPacketSequenceForBase(baseHostName, satteliteHostNames, satteliteChannelIDs, timeOutSecs)
    % Define the communication  packetSequence
    packetSequence = {};

    % Base sending to Sattelite-1 the number pi
    satteliteChannelID = satteliteChannelIDs{1};
    satteliteName = satteliteHostNames{1};
    direction = sprintf('%s -> %s', baseHostName, satteliteName);
    messageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, satteliteName);
    messageData = pi;
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID,...
        direction, ...
        messageLabel, 'withData', messageData, ...
        'timeOutSecs', timeOutSecs, ...                                    % Allow timeOutSecsto receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Base sending to Sattelite-2 the number pi^2
    satteliteName = satteliteHostNames{2};
    satteliteChannelID = satteliteChannelIDs{2};
    direction = sprintf('%s -> %s', baseHostName, satteliteName);
    messageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, satteliteName);
    messageData = pi^2;
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID,...
        direction, ...
        messageLabel, 'withData', messageData, ...
        'timeOutSecs', timeOutSecs, ...                                     % Allow timeOutSecs to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 2 ...
    );

    % Base sending to Sattelite-3 the number sqrt(pi)
    satteliteName = satteliteHostNames{3};
    satteliteChannelID = satteliteChannelIDs{3};
    direction = sprintf('%s -> %s', baseHostName, satteliteName);
    messageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, satteliteName);
    messageData = sqrt(pi);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID,...
        direction, ...
        messageLabel, 'withData', messageData, ...
        'timeOutSecs', timeOutSecs, ...                                     % Allow timeOutSecs to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 3 ...
    );

    % Base sending to Sattelite-1 the string "tra la la #1"
    satteliteName = satteliteHostNames{1};
    satteliteChannelID = satteliteChannelIDs{1};
    direction = sprintf('%s -> %s', baseHostName, satteliteName);
    messageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, satteliteName);
    messageData = 'tra la la #1';
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction,...
        messageLabel,  'withData', messageData, ...
        'timeOutSecs', timeOutSecs, ...                                        % Allow timeOutSecs to receive ACK (from remote host) that message was received
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );
    
    % Base sending to Sattelite-2 the string "tra la la #2"
    satteliteName = satteliteHostNames{2};
    satteliteChannelID = satteliteChannelIDs{2};
    direction = sprintf('%s -> %s', baseHostName, satteliteName);
    messageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, satteliteName);
    messageData = 'tra la la #2';
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction,...
        messageLabel,  'withData', messageData, ...
        'timeOutSecs', timeOutSecs, ...                                        % Allow timeOutSecs to receive ACK (from remote host) that message was received
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );
    
    % Base sending to Sattelite-3 the string "tra la la #3"
    satteliteName = satteliteHostNames{3};
    satteliteChannelID = satteliteChannelIDs{3};
    direction = sprintf('%s -> %s', baseHostName, satteliteName);
    messageLabel = sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, satteliteName);
    messageData = 'tra la la #3';
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction,...
        messageLabel,  'withData', messageData, ...
        'timeOutSecs', timeOutSecs, ...                                        % Allow timeOutSecsto receive ACK (from remote host) that message was received
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR}));
    );
    
    % Sattelite1 sending struct to base
    satteliteName = satteliteHostNames{1};
    satteliteChannelID = satteliteChannelIDs{1};
    direction = sprintf('%s <- %s', baseHostName, satteliteName);
    messageLabel = sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT',satteliteName);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction,...
        messageLabel, ...
        'timeOutSecs', timeOutSecs, ...                                         % Allow timeOutSecs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ... % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite2 sending struct to base
    satteliteName = satteliteHostNames{2};
    satteliteChannelID = satteliteChannelIDs{2};
    direction = sprintf('%s <- %s', baseHostName, satteliteName);
    messageLabel = sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT',satteliteName);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction,...
        messageLabel, ...
        'timeOutSecs', timeOutSecs, ...                                         % Allow timeOutSecs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ... % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite3 sending struct to base
    satteliteName = satteliteHostNames{3};
    satteliteChannelID = satteliteChannelIDs{3};
    direction = sprintf('%s <- %s', baseHostName, satteliteName);
    messageLabel = sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT',satteliteName);
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        direction, ...
        messageLabel, ...
        'timeOutSecs', timeOutSecs, ...                                         % Allow timeOutSecs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ... % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    figure(1); clf;
    
    x = zeros(1,100);
    y = zeros(1,100);
    for k = 1:100
        % Read cos-coeff from sattelite-1
        satteliteHostName = satteliteHostNames{1};
        direction = sprintf('%s <- %s', baseHostName, satteliteHostName);
        messageLabel = sprintf('SATTELITE(%s)___SENDING_COS_COEFF', satteliteHostName);
        packet = UDPBaseSatteliteCommunicator.makePacket(...
            satteliteChannelID, ...
            direction, ...
            messageLabel, ...
            'timeOutSecs', timeOutSecs, ...                                            % Allow this many secs to receive ACK (from remote host) that message was received 
            'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        );
    
        % Extract cos-coeff
        cos_coeff = packet.messageData;
    
        % Read sin-coeff from sattelite-2
        satteliteHostName = satteliteHostNames{2};
        direction = sprintf('%s <- %s', baseHostName, satteliteHostName);
        messageLabel = sprintf('SATTELITE(%s)___SENDING_SIN_COEFF', satteliteHostName);
        packet = UDPBaseSatteliteCommunicator.makePacket(...
            satteliteChannelID, ...
            direction, ...
            messageLabel, ...
            'timeOutSecs', timeOutSecs, ...                                            % Allow this many secs to receive ACK (from remote host) that message was received 
            'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        );
    
        % Extract sin-coeff
        cos_coeff = packet.messageData;
        
        % Read radial coeff from sattelite-3
        satteliteHostName = satteliteHostNames{3};
        direction = sprintf('%s <- %s', baseHostName, satteliteHostName);
        messageLabel = sprintf('SATTELITE(%s)___SENDING_RADIAL_COEFF', satteliteHostName);
        messageData = k;
        packet = UDPBaseSatteliteCommunicator.makePacket(...
            satteliteChannelID, ...
            direction, ...
            messageLabel, 'withData', messageData, ...
            'timeOutSecs', timeOutSecs, ...                                            % Allow this many secs to receive ACK (from remote host) that message was received 
            'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        );
    
        % Extract radial-coeff
        radial_coeff = packet.messageData;
        
        x(k) = radial_coeff*cos_coeff);
        y(k) = radial_coeff*sin_coeff);
        plot(x,y, '*-');
        drawnow;
    end
    
end