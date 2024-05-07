function [st, fileScenario, chunkNb] = LoadDt5(dataDir,FieldsDesired,FieldsToTranspose)
% LoadDt5                   Loads .dt5 files (outputs of ABSD)
%
% This function open the desired file or files and save the fields passed in a structure. .dt5 files
% are made of a cell array, with each row containing data chunks with various fields.
%
% dataDir                   either the full path to a single file, or an output of the dir() 
%                           function.
% FieldsDesired             cell vector containing the names of the fields in the datachunks to be
%                           saved. These fields names may change without warning between ABSD
%                           versions.
% FieldsToTranspose         empty or logical array (or double etc) the same size as FieldsDesired.
%                           This is used to compensate for some fields in the datachunk not having 
%                           their first dimension the temporal dimension that should be concatenated
%                           accross datachunks. Solution should be changed if at some point we need 
%                           fields with more than 2 dimensions, or that should be concatenated as 
%                           along an additional dimension (e.g. 'x').
%
% st                        structure containing the desired fields extracted from the .dt5 files
% fileScenario              cell array of the scenario named saved in each .dt5 file
% chunkNb                   array containing the number datachunks in each .dt5 file

if ischar(dataDir) % this is so one can use the path to a file instead of a dir for the function
    dataDir = dir(dataDir);
end
if isempty(FieldsToTranspose)
    FieldsToTranspose = zeros(length(FieldsDesired));
elseif length(FieldsToTranspose) ~= length(FieldsDesired)
    FieldsToTranspose = zeros(length(FieldsDesired));
    warning(['Length of FieldsToTranspose and FieldsDesired do not match. Using all zeros for' ...
        ' FieldsToTranspose instead']);
end

defaultFileSize = 3000;
fileNb = size(dataDir,1);
chunkNb = nan(fileNb,1);
fileScenario = cell(fileNb,1);
st1 = struct; % name for the structure used to store individual files data
st = struct; % name of the structure used to store the full data
for iFile = 1:fileNb
    [~,fileName,fileExtension]=fileparts(dataDir(iFile).name);

    % Check file type
    if ~strcmp(fileExtension,'.dt5')
        error('LoadDt5 can only load .dt5 files.')
    end

    if ~contains(fileName,'of')
        error(['LoadDt5 can only load recent .dt5 files. ''Recent'' .dt5 files ' ...
            'should contain XofX file numbering'])
    end

    % Open the file
    tempData = load([dataDir(iFile).folder filesep dataDir(iFile).name], '-mat');
    Data = tempData.ExperimentData;

    chunkNb(iFile) = size(Data,1);

    % Save scenario name
    if isfield(tempData, 'CommonData')
        fileScenario{iFile,1} = tempData.CommonData.ScenarioType.ScenarioName;
    end

    % Get data out of cells and save it in a structure for this specific file
    for iField = 1:length(FieldsDesired)
        fieldData = cellfun(@(s) getfield(s,FieldsDesired{iField}),Data,'uni',0);
        switch class(fieldData{iField})
            case {'double','single'}
                if ~isempty(FieldsToTranspose)
                    if FieldsToTranspose(iField)
                        st1.(FieldsDesired{iField}) = cell2mat(fieldData')';
                    else
                        st1.(FieldsDesired{iField}) = cell2mat(fieldData);
                    end
                else
                    st1.(FieldsDesired{iField}) = cell2mat(fieldData);
                end
            case 'logical'
                st1.(FieldsDesired{iField}) = cell2mat(cellfun(@(c) double(c),fieldData, 'uni', 0));
            case 'cell'
                if ~isempty(FieldsToTranspose)
                    if FieldsToTranspose(iField)
                        st1.(FieldsDesired{iField}) = cell2mat([fieldData{:}])';
                    else
                        st1.(FieldsDesired{iField}) = cell2mat([fieldData{:}]);
                    end
                else
                    st1.(FieldsDesired{iField}) = cell2mat([fieldData{:}]);
                end
            case 'char'
                st1.(FieldsDesired{iField}) = fieldData;
            case 'datetime'
                st1.(FieldsDesired{iField}) = [fieldData{:}]';
            otherwise
                st1.(FieldsDesired{iField}) = [];
                warning(['unsuported data type for field: ' FieldsDesired{iField}])
        end
    end

    if fileNb>1
        fprintf(['file ' dataDir(iFile).name ' (' num2str(iFile) ...
            '/' num2str(length(dataDir)) ') \n'])
        if iFile==1 %initialize large struct
            for iField = 1:length(FieldsDesired)
                fieldType = class(st1.(FieldsDesired{iField}));
                fieldSize = size(st1.(FieldsDesired{iField}));
                fieldSize(1) = fieldSize(1)/chunkNb(1);
                initSize = [fileNb*defaultFileSize*fieldSize(1) fieldSize(2:end)];
                idx = [{1:chunkNb(1)*fieldSize(1)}; repmat({':'},length(initSize)-1,1)];
                switch fieldType
                    case {'double','single','logical','cell'}
                        st.(FieldsDesired{iField}) = nan(initSize);
                        st.(FieldsDesired{iField})(idx{:}) = st1.(FieldsDesired{iField});
                    case 'char'
                        st.(FieldsDesired{iField}) = cell(initSize);
                        st.(FieldsDesired{iField}){idx{:}} = st1.(FieldsDesired{iField});
                    case 'datetime'
                        st.(FieldsDesired{iField}) = NaT(initSize);
                        st.(FieldsDesired{iField})(idx{:}) = st1.(FieldsDesired{iField});
                end
            end
        else % or fill it
            for iField = 1:length(FieldsDesired)
                fieldType = class(st1.(FieldsDesired{iField}));
                fieldSize = size(st1.(FieldsDesired{iField}));
                fieldSize(1) = fieldSize(1)/chunkNb(iFile);
                idx = [{sum(chunkNb(1:iFile-1))*fieldSize(1)+1:...
                    sum(chunkNb(1:iFile))*fieldSize(1)};...
                    repmat({':'},length(fieldSize)-1,1)];
                % idx = [{idx{1}(1):idx{1}(end); repmat({':'},length(fieldSize)-1,1)];
                % astuce repmate fait :,:,:) avec le bon nombre de :
                % idx{1}(1) = nb total de datachunk avant ce fichier * taille de ce field suivant
                %              la premiere dimension
                switch fieldType
                    case {'double','single','logical','cell'}
                        st.(FieldsDesired{iField})(idx{:}) = st1.(FieldsDesired{iField});
                    case 'char'
                        st.(FieldsDesired{iField}){idx{:}} = st1.(FieldsDesired{iField});
                    case 'datetime'
                        st.(FieldsDesired{iField})(idx{:}) = st1.(FieldsDesired{iField});
                end
            end
        end
    else
        st = st1;
    end
end

% truncate trailing nans
if fileNb>1
    for iField = 1:length(FieldsDesired)
        fieldType = class(st1.(FieldsDesired{iField}));
        fieldSize = size(st1.(FieldsDesired{iField}));
        fieldSize(1) = fieldSize(1)/chunkNb(end);
        initSize = [fileNb*defaultFileSize*fieldSize(1) fieldSize(2:end)];

        idx = [{sum(chunkNb,'omitnan')*fieldSize(1)+1:initSize(1)}; ...
            repmat({':'},length(fieldSize)-1,1)];

        switch fieldType
            case {'double','single','logical','cell'}
                st.(FieldsDesired{iField})(idx{:}) = [];
            case 'char'
                st.(FieldsDesired{iField}){idx{:}} = [];
            case 'datetime'
                st.(FieldsDesired{iField})(idx{:}) = [];
        end
    end
end
end

