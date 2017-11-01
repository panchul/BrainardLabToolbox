function shortBaseMultiSatteliteDemo

    %% Define a 2-sattelite scheme
    baseHostName = 'manta';
    sattelite1HostName = 'ionean';
    sattelite2HostName = 'gka06';
    sattelite3HostName = 'monkfish';
    
    hostNames       = {baseHostName,    sattelite1HostName,  sattelite2HostName,  sattelite3HostName};
    hostIPs         = {'128.91.12.90',  '128.91.12.144',     '128.91.12.160',     '128.91.12.161'};
    hostRoles       = {'base',          'sattelite',         'sattelite',         'sattelite'};
    commPorts       = {nan,              2007,               2008,                2009};
        
    %% Define a 1-sattelite scheme
%     hostNames       = {baseHostName,    sattelite1HostName};
%     hostIPs         = {'128.91.12.90',  '128.91.12.144'};
%     hostRoles       = {'base',          'sattelite'};
%     commPorts       = {nan,              2010};
    
    %% Control what is printed on the command window
    beVerbose = false;
    displayPackets = true;
    
    %% Instantiate our UDPcommunicator object
    UDPobj = UDPBaseSatteliteCommunicator.instantiateObject(hostNames, hostIPs, hostRoles, commPorts, beVerbose);
    
    %% Make the packetSequences
    if (contains(UDPobj.localHostName, baseHostName))
        if (numel(hostNames) == 4)
            packetSequence = designPacketSequenceForBaseWithThreeSatellites(baseHostName, sattelite1HostName, sattelite2HostName, sattelite3HostName,...
                UDPobj.satteliteInfo(sattelite1HostName).satteliteChannelID, UDPobj.satteliteInfo(sattelite2HostName).satteliteChannelID, UDPobj.satteliteInfo(sattelite3HostName).satteliteChannelID);
        elseif (numel(hostNames) == 3)
            packetSequence = designPacketSequenceForBaseWithTwoSatellites(baseHostName, sattelite1HostName, sattelite2HostName, ...
                UDPobj.satteliteInfo(sattelite1HostName).satteliteChannelID, UDPobj.satteliteInfo(sattelite2HostName).satteliteChannelID);
        elseif (numel(hostNames) == 2)
            packetSequence = designPacketSequenceForBaseWithOneSatellite(baseHostName, sattelite1HostName, UDPobj.satteliteInfo(sattelite1HostName).satteliteChannelID);
        end
        
    elseif (contains(UDPobj.localHostName, sattelite2HostName))
        packetSequence = designPacketSequenceForSattelite2(baseHostName, sattelite2HostName, UDPobj.satteliteInfo(sattelite2HostName).satteliteChannelID);
        
    elseif (contains(UDPobj.localHostName, sattelite1HostName))
        packetSequence = designPacketSequenceForSattelite1(baseHostName, sattelite1HostName, UDPobj.satteliteInfo(sattelite1HostName).satteliteChannelID);
    end
    
    %% Establish the communication
    triggerMessage = 'Go!';
    allSattelitesAreAGOMessage = 'All Sattelites Are A GO!';
    UDPobj.initiateCommunication(hostRoles,  hostNames, triggerMessage, allSattelitesAreAGOMessage, 'beVerbose', beVerbose);
    
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
function packetSequence = designPacketSequenceForSattelite1(baseHostName, satteliteHostName, satteliteChannelID)
    % Define the communication  packetSequence
    packetSequence = {};
    
    % Base sending
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        sprintf('%s -> %s', baseHostName, satteliteHostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, satteliteHostName),...
        'timeOutSecs', 4.0, ...                                                     % Wait for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...     % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Base sending
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID,...
        sprintf('%s -> %s', baseHostName, satteliteHostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, satteliteHostName),...
        'timeOutSecs', 4.0, ...                                                    % Wait for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...           % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite-2 sending
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID,...
        sprintf('%s <- %s', baseHostName, satteliteHostName), sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT', satteliteHostName),...
        'timeOutSecs', 4.0, ...                                                     % Allow 1 sec to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', struct('a', 12, 'b', rand(10,10)));
end

%
% DESIGN PACKET SEQUENCE FOR SATTELITE-2
%
function packetSequence = designPacketSequenceForSattelite2(baseHostName, satteliteHostName, satteliteChannelID)
    % Define the communication  packetSequence
    packetSequence = {};
    
    % Base sending
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        sprintf('%s -> %s', baseHostName, satteliteHostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, satteliteHostName),...
        'timeOutSecs', 4.0, ...                                                     % Wait for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...     % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Base sending 
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
         sprintf('%s -> %s', baseHostName, satteliteHostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, satteliteHostName),...
         'timeOutSecs', 4.0, ...                                                    % Wait for 1 secs to receive this message
         'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...           % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
         'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite-2 sending
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        sprintf('%s <- %s', baseHostName, satteliteHostName), sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT', satteliteHostName),...
        'timeOutSecs', 4.0, ...                                             % Allow 1 sec to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', struct('a', 12, 'b', rand(20,20)));
end

%
% DESIGN PACKET SEQUENCE FOR SATTELITE-3
%
function packetSequence = designPacketSequenceForSattelite3(baseHostName, satteliteHostName, satteliteChannelID)
    % Define the communication  packetSequence
    packetSequence = {};
    
    % Base sending
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        sprintf('%s -> %s', baseHostName, satteliteHostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, satteliteHostName),...
        'timeOutSecs', 4.0, ...                                                     % Wait for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...            % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...     % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Base sending 
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
         sprintf('%s -> %s', baseHostName, satteliteHostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, satteliteHostName),...
         'timeOutSecs', 4.0, ...                                                    % Wait for 1 secs to receive this message
         'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...           % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
         'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite-3 sending
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        sprintf('%s <- %s', baseHostName, satteliteHostName), sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT', satteliteHostName),...
        'timeOutSecs', 4.0, ...                                             % Allow 1 sec to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', struct('a', 12, 'b', rand(30,30)));
end


%
% DESIGN PACKET SEQUENCE FOR BASE (MANTA) WITH 3 SATTELITES
%
function packetSequence = designPacketSequenceForBaseWithThreeSatellites(baseHostName, sattelite1HostName, sattelite2HostName, sattelite3HostName, sattelite1ChannelID, sattelite2ChannelID, sattelite3ChannelID)
    % Define the communication  packetSequence
    packetSequence = {};

    % Base sending (int: +1), Sattelite1 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite1ChannelID,...
        sprintf('%s -> %s', baseHostName, sattelite1HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, sattelite1HostName),...
        'timeOutSecs', 4.0, ...                                             % Allow 1 sec to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 1 ...
    );

    % Base sending (int: +1), Sattelite2 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite2ChannelID, ...
        sprintf('%s -> %s', baseHostName, sattelite2HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER',baseHostName, sattelite2HostName),...
        'timeOutSecs', 4.0, ...                                             % Allow 1 sec to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', -1 ...
    );

    % Base sending (int: +2), Sattelite3 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite3ChannelID, ...
        sprintf('%s -> %s', baseHostName, sattelite3HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER',baseHostName, sattelite3HostName),...
        'timeOutSecs', 4.0, ...                                             % Allow 1 sec to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', -1 ...
    );


    % Base sending (char: tra la la #1), Sattelite1 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite1ChannelID, ...
        sprintf('%s -> %s', baseHostName, sattelite1HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, sattelite1HostName),...
        'timeOutSecs', 4.0, ...                                                 % Allow 1 sec to receive ACK (from remote host) that message was received
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 'tra la la #1');
    
    % Base sending (char: tra la la #2), Sattelite2 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite2ChannelID, ...
        sprintf('%s -> %s', baseHostName, sattelite2HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING',baseHostName, sattelite1HostName), ...
        'timeOutSecs', 4.0, ...                                                 % Allow 1 sec to receive ACK (from remote host) that message was received
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 'tra la la #2');
    
    % Base sending (char: tra la la #3), Sattelite3 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite3ChannelID, ...
        sprintf('%s -> %s', baseHostName, sattelite3HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING',baseHostName, sattelite3HostName), ...
        'timeOutSecs', 4.0, ...                                                 % Allow 1 sec to receive ACK (from remote host) that message was received
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 'tra la la #3');
    
    
    % Sattelite1 sending, Base receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite1ChannelID, ...
        sprintf('%s <- %s', baseHostName, sattelite1HostName), sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT',sattelite1HostName),...
        'timeOutSecs', 4.0, ...                                                 % Allow for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ... % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite2 sending, Manta receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite2ChannelID, ...
        sprintf('%s <- %s', baseHostName, sattelite2HostName), sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT',sattelite2HostName),...
        'timeOutSecs', 4.0, ...                                                 % Allow for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ... % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite3 sending, Manta receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite3ChannelID, ...
        sprintf('%s <- %s', baseHostName, sattelite3HostName), sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT',sattelite3HostName),...
        'timeOutSecs', 4.0, ...                                                 % Allow for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ... % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

end


%
% DESIGN PACKET SEQUENCE FOR BASE (MANTA) WITH 2 SATTELITES
%
function packetSequence = designPacketSequenceForBaseWithTwoSatellites(baseHostName, sattelite1HostName, sattelite2HostName, sattelite1ChannelID, sattelite2ChannelID)
    % Define the communication  packetSequence
    packetSequence = {};

    % Base sending (int: +1), Sattelite1 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite1ChannelID,...
        sprintf('%s -> %s', baseHostName, sattelite1HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER', baseHostName, sattelite1HostName),...
        'timeOutSecs', 4.0, ...                                             % Allow 1 sec to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 1 ...
    );

     % Base sending (int: +1), Sattelite2 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite2ChannelID, ...
        sprintf('%s -> %s', baseHostName, sattelite2HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_SINGLE_INTEGER',baseHostName, sattelite2HostName),...
        'timeOutSecs', 4.0, ...                                             % Allow 1 sec to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', -1 ...
    );


    % Base sending (char: tra la la #1), Sattelite1 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite1ChannelID, ...
        sprintf('%s -> %s', baseHostName, sattelite1HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING', baseHostName, sattelite1HostName),...
        'timeOutSecs', 4.0, ...                                                 % Allow 1 sec to receive ACK (from remote host) that message was received
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 'tra la la #1');
    
    % Base sending (char: tra la la #2), Sattelite2 receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite2ChannelID, ...
        sprintf('%s -> %s', baseHostName, sattelite2HostName), sprintf('BASE(%s)_TO_SATTELITE(%s)___SENDING_CHAR_STRING',baseHostName, sattelite1HostName), ...
        'timeOutSecs', 4.0, ...                                                 % Allow 1 sec to receive ACK (from remote host) that message was received
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 'tra la la #2');
    
    
    % Sattelite1 sending, Base receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite1ChannelID, ...
        sprintf('%s <- %s', baseHostName, sattelite1HostName), sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT',sattelite1HostName),...
        'timeOutSecs', 4.0, ...                                                 % Allow for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ... % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );

    % Sattelite2 sending, Manta receiving
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        sattelite2ChannelID, ...
        sprintf('%s <- %s', baseHostName, sattelite2HostName), sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT',sattelite2HostName),...
        'timeOutSecs', 4.0, ...                                                 % Allow for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ... % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );
end

%
% DESIGN PACKET SEQUENCE FOR BASE WITH 1 SATTELITE
%
function packetSequence = designPacketSequenceForBaseWithOneSatellite(baseHostName, satteliteHostName, satteliteChannelID)
    % Define the communication  packetSequence
    packetSequence = {};
    
    % BAse sending (int: +1)
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        sprintf('%s -> %s', baseHostName, satteliteHostName), sprintf('BASE(%s)___SENDING_SINGLE_INTEGER',baseHostName), ...
        'timeOutSecs', 4.0, ...                                             % Allow 1 sec to receive ACK (from remote host) that message was received 
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...    % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 1 ...
    );

    % Base sending (char: tra la la #1)
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        sprintf('%s -> %s', baseHostName, satteliteHostName), sprintf('BASE(%s)___SENDING_CHAR_STING',baseHostName), ...
        'timeOutSecs', 4.0, ...                                                 % Allow 1 sec to receive ACK (from remote host) that message was received
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'withData', 'tra la la #1');
    
    % Sattelite sending
    packetSequence{numel(packetSequence)+1} = UDPBaseSatteliteCommunicator.makePacket(...
        satteliteChannelID, ...
        sprintf('%s <- %s', baseHostName, satteliteHostName), sprintf('SATTELITE(%s)___SENDING_SMALL_STRUCT',satteliteHostName),...
        'timeOutSecs', 4.0, ...                                                 % Allow for 1 secs to receive this message
        'timeOutAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER, ...        % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
        'badTransmissionAction', UDPBaseSatteliteCommunicator.NOTIFY_CALLER ... % Do not throw an error, notify caller function instead (choose from UDPBaseSatteliteCommunicator.{NOTIFY_CALLER, THROW_ERROR})
    );
end

