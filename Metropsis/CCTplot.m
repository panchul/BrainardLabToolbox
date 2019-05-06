function theFig = CCTplot(fName,varargin)
% Plots discrimination points using data from Cambridge Colour Test text files
%
% Syntax:
%    theFig = CCTplot(fName)
%
%
% Description:
%    The Metropsis system implements the Cambridge Colour Test and outputs
%    data in an idiosyncratic file format.  This routine parses that file
%    to obtain the threshold contour in the u',v' chromaticity plane and
%    makes a plot.
%
% Inputs
%     fName          - Matlab string with filename. Can be relative to
%                      Matlab's current working directory, or absolute.
%
% Outputs:
%     theFig         - Handle to the plot
%
% Optional key/value pairs
%     'figHandle'    - Figure handle to plot in.  Creates new figure if empty
%                      (default empty).
%     'plotColor'    - Color arg accepted by plot.
%
% See also:
%

% History:
%    04/11/19  dce       Wrote it.  File parsing code provided by ncp.
%    04/12/19  dce, dhb  Comments and tweaking.

% Examples:
%{
    % Need to point to a data file available on the machine this is being
    % run on.
    CCTplot('/Users/geoffreyaguirre/Documents/Deena CCT spreadsheets/TOME_DEENA_2.txt')
    CCTplot('/Volumes/Users1/Dropbox (Aguirre-Brainard Lab)/MTRP_data/Exp_CCTE/Subject_TOME_BURGE/TOME_BURGE_1.txt')
    CCTplot('/Volumes/Users1/Dropbox (Aguirre-Brainard Lab)/MTRP_data/Exp_CCTE/Subject_DEENA ELUL/DEENA ELUL_2 copy.txt')
%}

% Close figures
close all;

% Parse key/value pairs
p = inputParser;
p.addParameter('figHandle',[],@(x) (isempty(x) | ishandle(x)));
p.addParameter('plotColor','r',@(x) (ischar(x) | isvector(x)));
p.parse(varargin{:});

% Read the file
[center_v_prime_w, center_u_prime_w, azimuthsTable] = ParseCCTTextfile(fName);

% Get table length
highestIndex = size(azimuthsTable, 1);

% Calculate and store u_prime coordinates
u_prime = zeros(highestIndex,1);
for i = 1:highestIndex
    u_prime(i) = cos(azimuthsTable(i,3)) * azimuthsTable(i,1) + center_u_prime_w;
end

% Calculate and store v_prime coordinates
v_prime = zeros(highestIndex,1);
for i = 1:highestIndex
    v_prime(i) = sin(azimuthsTable(i,3)) * azimuthsTable(i,1) + center_v_prime_w;
end

% Try to fit an ellipse to the data
%
% We have several ellipse fitting routines.
theData = [u_prime-center_u_prime_w v_prime-center_v_prime_w zeros(size(u_prime))]';
initialFactor = 15;
ellRanges = max(theData,[],2)-min(theData,[],2);
ellParams0 = [1./ellRanges'.^0.5 0 0 0]';
ellParams0(1:3) = ellParams0(1:3)*initialFactor;
ellParams0(isinf(ellParams0)) = 1;
[fitA,fitAinv,fitQ,fitEllParams] = EllipsoidFit(theData,ellParams0,false,true);
fitCenter = [center_u_prime_w center_v_prime_w 0]';

% Get ellipse from fit
nThetaEllipse = 200;
circleIn2D = UnitCircleGenerate(nThetaEllipse);
circleIn3DPlane = [circleIn2D(1,:) ; circleIn2D(2,:) ; zeros(size(circleIn2D(1,:)))];
fitEllipseIn3DPlane = PointsOnEllipsoidFind(fitQ,circleIn3DPlane,fitCenter);
fitEllipseIn2D = fitEllipseIn3DPlane(1:3,:);

% Plot u_prime and v_prime
if (isempty(p.Results.figHandle))
    theFig = figure; clf; hold on
    set(theFig,'Position',[15   630   900   700]);
end
set(gca,'FontName','Helvetica','FontSize',16);
plot(u_prime,v_prime,'ro','MarkerEdgeColor',p.Results.plotColor,'MarkerFaceColor',p.Results.plotColor','MarkerSize',10);
plot(center_u_prime_w, center_v_prime_w, 'b*','MarkerSize',8);
plot(fitEllipseIn2D(1,:),fitEllipseIn2D(2,:),'g','LineWidth',2);
xlim([0.1 0.3]);
ylim([0.35 0.55]);
axis('square');
xlabel(LiteralUnderscore('u_prime'),'FontSize',18);
ylabel(LiteralUnderscore('v_prime'),'FontSize',18);

end

% Function for parsing the text file
function [v_prime_w, u_prime_w, azimuthsTable] = ParseCCTTextfile(fName)

% Retrieve v_prime_w, u_prime_w
[v_prime_w, u_prime_w] = getValuesOfUVprimeW(fName);

% Retrieve azimuths table
azimuthsTable = getAzimuthsTable(fName);
end

function azimuthsTable = getAzimuthsTable(fName)

azimuthsTable = [];

% Lines we are searching for before we start extracting the azimuths table
targetLine1 = 'Saturation';
targetLine2 = 'Std';

% Open file
fid = fopen(fName);

% Scan file one line at a time
tline = fgetl(fid);

while ischar(tline)
    % check for targetLine1
    if contains(tline, targetLine1)
        % check for targetLine2
        tline = fgetl(fid);
        if (contains(tline, targetLine2))
            keepLooping = true;
            while (keepLooping)
                % keep reading lines and filling table long as they start with 'azimuth'
                azimuthTableRowVals = getAzimuthTableRowFromLineString(fgetl(fid));
                if (isempty(azimuthTableRowVals))
                    % All done
                    keepLooping = false;
                else
                    % Insert row
                    row = size(azimuthsTable,1)+1;
                    azimuthsTable(row,:) = azimuthTableRowVals;
                end
            end % while (keepLooping)
        else
            fprintf('Did not detect line: ''%s''.', targetLine2);
        end
    end
    % Read next line
    tline = fgetl(fid);
end
fclose(fid);
%disp(azimuthsTable);

end

function vals = getAzimuthTableRowFromLineString(lineString)
[~, notMatched] = regexp(lineString,'\s+', 'match', 'split');
% Check that first item is 'azimuth'
if (strcmp(notMatched{1}, 'azimuth'))
    vals(1) = str2double(notMatched{2});
    vals(2) = str2double(notMatched{3});
    vals(3) = str2double(notMatched{6});
else
    vals = [];
end
end


function [v_prime_w, u_prime_w] = getValuesOfUVprimeW(fName)

% Lines we are searching for before we start extracting the v_prime_w, u_prime_w
targetLine1 = 'Independent Variables';
targetLine2 = 'Value';

% Open file
fid = fopen(fName);

% Scan first line
tline = fgetl(fid);

% Scan file one line at a time
while ischar(tline)
    % check for targetLine1
    if contains(tline, targetLine1)
        % Read the targetLine2
        tline = fgetl(fid);
        if (contains(tline, targetLine2))
            % It is, read next 2 lines to get the 'v_prime_w' and 'u_prime_w' values
            v_prime_w = getPropertyValueFromLineString(fgetl(fid), 'v_prime_w');
            u_prime_w = getPropertyValueFromLineString(fgetl(fid), 'u_prime_w');
        else
            fprintf('Did not detect line: ''%s''.', targetLine2);
        end
    end
    % Read next line
    tline = fgetl(fid);
end
fclose(fid);

end

function val = getPropertyValueFromLineString(lineString, propertyName)
splitStr = regexp(lineString,propertyName,'split');
if (numel(splitStr) < 2)
    error(sprintf('Did not find a value in line: ''%s'' for property named: ''%s''.', lineString, propertyName));
else
    val = str2double(splitStr{2});
end
end


