function [time,isUpdating,predictionWeight, ...
    yDesired,probaPredicted,State,yPredicted, raw, X, trigs] = loadData1(datafolder, datafiles)

    % Get number of files
    nFiles = length(datafiles);

    % Initialize the fields with approximately the right duration
    % (what's unknown at this point is the duration of the last .dt5 file)
    
    trigs=[];
    nSamples=0;
        for i = 1:nFiles
        S=load(fullfile(datafolder,datafiles{i}),'-mat');
        ExperimentData=S.ExperimentData;
        nSamples = nSamples + length(ExperimentData);
        end
    sample = 0;
    for i = 1:nFiles
        % Load the file
        S=load(fullfile(datafolder,datafiles{i}),'-mat');
        ExperimentData=S.ExperimentData;
        % Get number of points
        nPoints = length(ExperimentData);

        % Get first timestamp and size of the feature space
        if i == 1
            startTime = ExperimentData{1}.Time;
            nstates = length(ExperimentData{1}.State);
            n_chans = size(ExperimentData{1}.x,3);
            try
            n_trigs = size(ExperimentData{1}.AdditionalChannels,1);
            trigs = zeros(n_trigs,nSamples);
            end
            time = zeros(1,nSamples);
            isUpdating = zeros(1,nSamples); 
            predictionWeight = zeros(nstates,nSamples);   
            yDesired = zeros(nstates,nSamples);
            yPredicted = zeros(nstates,nSamples);
            probaPredicted = zeros(nstates,nSamples);
            State = zeros(nstates,nSamples);
            raw = zeros(n_chans,nSamples*59);           
            X = zeros([size(ExperimentData{1}.x) nSamples]);
        end

        % Get fields
        
        for j = 1:nPoints
            sample = sample+1;
            time(sample) = seconds(ExperimentData{j}.Time-startTime);
            isUpdating(sample) = ExperimentData{j}.IsUpdating;
            %predictionWeight(:,sample) = ExperimentData{j}.ScenarioSupplementaryData.PredictionWeight;
            yDesired(:,sample) = [0 ExperimentData{j}.yDesired];
            State(:,sample) = ExperimentData{j}.State;
            probaPredicted(:,sample) = ExperimentData{j}.AlphaPredicted{1};
            raw(:,1+59*(sample-1):sample*59) = ExperimentData{j}.RawDataBuffer; 
            X(:,:,:,sample) = ExperimentData{j}.x; 
            yPredicted(:,sample) = [0 ExperimentData{j}.y];
            try
            trigs(:,sample) = sum((ExperimentData{j}.AdditionalChannels)>1);
            end
            %threshold(sample) = ExperimentData{j}.ScenarioSupplementaryData.SpeedThresholds;
        end
       
    end
end

