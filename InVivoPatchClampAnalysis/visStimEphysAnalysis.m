function [meanResponseTuningCurveCentered, stdResponseTuningCurveCentered, CVResponseTuningCurveCentered,...
    meanResponseTuningCurveDistToSpikeCentered,stdResponseTuningCurveSubDistToSpikeCentered,...
    CVResponseTuningCurveSubDistToSpikeCentered, VspikeThresholdMean,trialSubDistAPData,R_AP, R_sub]...
    = visStimEphysAnalysis(X,samplingFreq,angles,angleTimingsSorted,durationOfDrift_sec, ...
    durationOfGrey_sec,peakDetectionHeightDiscountFactor,minPeakHeight,mpw)
%% paramaters
nAngles = length(angles);
[~, nFiles] = size(X);
baselineDurationFrames = round(durationOfGrey_sec*samplingFreq);
driftDurationFrames = round(durationOfDrift_sec*samplingFreq);
angleFramingsSorted = round(angleTimingsSorted*samplingFreq);
%% find APs
[pkLocs, ~, XAPs, Xsub, APThreshold] = findAPlocs(X, samplingFreq, minPeakHeight, peakDetectionHeightDiscountFactor, mpw);
%pkLocs holds location of peaks
%XAP holds AP location as 0 and 1
%Xsub holds subthreshold depol, APs are removed and replaced with NaNs
%APThresholdP gives a  threshold per AP 
trialSubDistAPData = [Xsub,XAPs]; %for output
Xnorm = X-quantile(X,0.05); %subtract out resting potential/baseline from all traces
VspikeThresholdMean = nanmedian(APThreshold);

%% segment Files based on angleTimings
Xsorted = nan(nFiles,nAngles,driftDurationFrames+baselineDurationFrames,3); %for each file, and angle, holds response to stim (including 1s baseline, 2s drift); last dim for Xsub vs XAP vs raw trace)
for iFile = 1:nFiles
    for iAngle = 1:nAngles
     Xsorted(iFile,iAngle,:,1) = Xsub(angleFramingsSorted(iAngle,iFile)-baselineDurationFrames:angleFramingsSorted(iAngle,iFile)+driftDurationFrames-1,iFile);  
     Xsorted(iFile,iAngle,:,2) = XAPs(angleFramingsSorted(iAngle,iFile)-baselineDurationFrames:angleFramingsSorted(iAngle,iFile)+driftDurationFrames-1,iFile);  
     Xsorted(iFile,iAngle,:,3) = Xnorm(angleFramingsSorted(iAngle,iFile)-baselineDurationFrames:angleFramingsSorted(iAngle,iFile)+driftDurationFrames-1,iFile);  
    end
end
%% calculate mean and stdev tuning curves for subthreshold and AP responses

qDistToSpike = 0.95; %quantile to assess subthreshold potential for distance to spike
qSubThresh = 0.5; %quantile to assess subthreshold potential

%calculate  grey response (sub and AP), this is used as a baseline response
%to light that will be subtracted from the orienation evoked response
trialMeanGreyResponseSub = quantile(Xsorted(:,:,1:baselineDurationFrames,1),0.05,3); 
trialMeanGreyResponseAPFreq = nanmedian((nanmean(nansum(Xsorted(:,:,1:baselineDurationFrames,2),3),2))/durationOfGrey_sec); %average across all greys for APs to minimize noise

%calculate orinetaiton-specific depolarizaiton ( response for orientation -  response for grey): 
trialResponseTuningCurveSub = quantile(Xsorted(:,:,baselineDurationFrames+1:end,1),qSubThresh,3)-trialMeanGreyResponseSub; %meaned across trials
trialResponseTuningCurveAPFreq = ((nansum(Xsorted(:,:,baselineDurationFrames+1:end,2),3))/durationOfDrift_sec)-(trialMeanGreyResponseAPFreq); %meaned across trials

%calculate distance to spike generated by orientation-evoked
%depolarization, by subtracting threshold
trialResponseTuningCurveSubDistanceToSpike = (quantile(Xsorted(:,:,baselineDurationFrames+1:end,1),qDistToSpike,3)-VspikeThresholdMean);%nanmedian(adaptiveVspikeThrehsoldSorted(:,:,baselineDurationFrames+1:end),3);

%for each set of responses calculated (subthrehsold, distance to spike, AP), these variables hold the values for the first and second half of the response window, which is 2s.
%the stimulus is 1Hz so 2 cycles are present per response window.
%Partioning of responses will allow assessment of response reliability
%during stim presentation in subsequent analysis
trialResponseTuningCurveSubFirstHalf = quantile(Xsorted(:,:,baselineDurationFrames+1:end-round(driftDurationFrames/2),1),qSubThresh,3)-trialMeanGreyResponseSub; %meaned across trials
trialResponseTuningCurveSubSecondHalf = quantile(Xsorted(:,:,baselineDurationFrames+1+round(driftDurationFrames/2)+1:end,1),qSubThresh,3)-trialMeanGreyResponseSub; %meaned across trials
trialResponseTuningCurveSubFirstHalf_distToSpike = (quantile(Xsorted(:,:,baselineDurationFrames+1:end-round(driftDurationFrames/2),1),qDistToSpike,3)-VspikeThresholdMean); %meaned across trials
trialResponseTuningCurveSubSecondHalf_distToSpike = (quantile(Xsorted(:,:,baselineDurationFrames+1+round(driftDurationFrames/2)+1:end,1),qDistToSpike,3)-VspikeThresholdMean); %meaned across trials
trialResponseTuningCurveAPFreqFirstHalf = (nansum(Xsorted(:,:,baselineDurationFrames+1:end-round(driftDurationFrames/2),2),3))/(durationOfDrift_sec/2)-(trialMeanGreyResponseAPFreq); %meaned across trials
trialResponseTuningCurveAPFreqSecondHalf = (nansum(Xsorted(:,:,baselineDurationFrames+1+round(driftDurationFrames/2)+1:end,2),3))/(durationOfDrift_sec/2)-(trialMeanGreyResponseAPFreq); %meaned across trials
R_AP =[trialResponseTuningCurveAPFreqFirstHalf;trialResponseTuningCurveAPFreqSecondHalf]; %stores AP responses to each cycle of stim
R_sub =[trialResponseTuningCurveSubFirstHalf;trialResponseTuningCurveSubSecondHalf]; %stores sub responses to each cycle of stim

%re order responses to match file order
fileIdx = repmat([1:nFiles]',2,1);
orderIdx = [];
for iFile = 1:nFiles
   orderIdx = [orderIdx; find(fileIdx==iFile)];
end
R_AP = R_AP(orderIdx,:);
R_sub = R_sub(orderIdx,:);

%calculate mean for each set of responses  (subthrehsold, distance to spike, AP)
meanResponseTuningCurveSub = nanmean(trialResponseTuningCurveSub,1);
meanResponseTuningCurveAPFreq = nanmean(trialResponseTuningCurveAPFreq,1);
meanResponseTuningCurve = [meanResponseTuningCurveSub;meanResponseTuningCurveAPFreq];
meanResponseTuningCurveDistToSpike = nanmean(trialResponseTuningCurveSubDistanceToSpike,1);

%calculate std for each set of responses  (subthrehsold, distance to spike, AP)
stdResponseTuningCurveSub = nanmean([nanstd(trialResponseTuningCurveSubFirstHalf,[],1);nanstd(trialResponseTuningCurveSubSecondHalf,[],1)]);
stdResponseTuningCurveAPFreq = nanmean([nanstd(trialResponseTuningCurveAPFreqFirstHalf,[],1);nanstd(trialResponseTuningCurveAPFreqSecondHalf,[],1)]);
stdResponseTuningCurve = [stdResponseTuningCurveSub;stdResponseTuningCurveAPFreq];
stdResponseTuningCurveSubDistToSpike = nanmean([nanstd(trialResponseTuningCurveSubFirstHalf_distToSpike,[],1);nanstd(trialResponseTuningCurveSubSecondHalf_distToSpike,[],1)]);

%average directions (each orientation has 2 directions)
meanResponseTuningCurve = (meanResponseTuningCurve(:,1:6)+meanResponseTuningCurve(:,7:12));
meanResponseTuningCurve = (meanResponseTuningCurve/2);
stdResponseTuningCurve = (stdResponseTuningCurve(:,1:6)+stdResponseTuningCurve(:,7:12));
stdResponseTuningCurve = (stdResponseTuningCurve/2);
meanResponseTuningCurveDistToSpike = (meanResponseTuningCurveDistToSpike(:,1:6)+meanResponseTuningCurveDistToSpike(:,7:12));
meanResponseTuningCurveDistToSpike = (meanResponseTuningCurveDistToSpike/2);
stdResponseTuningCurveSubDistToSpike = (stdResponseTuningCurveSubDistToSpike(:,1:6)+stdResponseTuningCurveSubDistToSpike(:,7:12));
stdResponseTuningCurveSubDistToSpike = (stdResponseTuningCurveSubDistToSpike/2);

%center curve
[~, centeringIdxsSub] = CenterTuningCurve(meanResponseTuningCurve(1,:));
[~, centeringIdxsAP] = CenterTuningCurve(meanResponseTuningCurve(2,:));

if sum(meanResponseTuningCurve(2,:))>0 %center tuning curve based on spikes, otherwise center on subthrehold potential
centeringIdxs = [centeringIdxsAP;centeringIdxsAP];
else
centeringIdxs = [centeringIdxsSub;centeringIdxsSub];
end

%initaite variables holding centered tuning curve
meanResponseTuningCurveCentered = nan(2,nAngles/2);
stdResponseTuningCurveCentered = nan(2,nAngles/2);
meanResponseTuningCurveDistToSpikeCentered = nan(1,nAngles/2);
stdResponseTuningCurveSubDistToSpikeCentered = nan(1,nAngles/2);

for iSuborAP = 1:2
for iAngle=1:nAngles/2
meanResponseTuningCurveCentered(iSuborAP,centeringIdxs(iSuborAP,iAngle)) = meanResponseTuningCurve(iSuborAP,iAngle);
stdResponseTuningCurveCentered(iSuborAP,centeringIdxs(iSuborAP,iAngle)) = stdResponseTuningCurve(iSuborAP,iAngle);
    
    if iSuborAP==1
    meanResponseTuningCurveDistToSpikeCentered(1,centeringIdxs(1,iAngle)) = meanResponseTuningCurveDistToSpike(1,iAngle);
    stdResponseTuningCurveSubDistToSpikeCentered(1,centeringIdxs(1,iAngle)) = stdResponseTuningCurveSubDistToSpike(1,iAngle);
    end
    
end
end

%calculate CV for curves
CVResponseTuningCurveCentered = (stdResponseTuningCurveCentered./meanResponseTuningCurveCentered);
CVResponseTuningCurveCentered((meanResponseTuningCurveCentered)<0.2)=NaN; %if mean is too small ignore else noisy
CVResponseTuningCurveSubDistToSpikeCentered = abs((stdResponseTuningCurveSubDistToSpikeCentered./meanResponseTuningCurveDistToSpikeCentered));
CVResponseTuningCurveSubDistToSpikeCentered((abs(meanResponseTuningCurveDistToSpikeCentered))<0.2)=NaN; %if mean is too small ignore else noisy



%%
