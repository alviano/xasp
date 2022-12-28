enabled(121).
enabled(1).
enabled(86581).
%enabled(181).
enabled(0).

time(0).
%now(181).
%time(181).
obs(exposureSurvey_exposureSurveyCompleted,true,1).
obs(symptomsSurvey_symptomsSurveyCompleted,true,1).
obs(tempCheck_checkpointVisited,true,1).
obs(testingResults_needsNegTestsForAssumedInfectiousWithProbHigh,true,1).
obs(testingSurvey_posPcrTest,true,1).
obs(testingSurvey_testingSurveyCompleted,true,1).
obs(clearance_clearanceReceivedAfterAssumedInfectious,true,121).
% States

fluent(core_readyToReturn,pos_defined).
state(core_readyToReturn).
compliantState(core_readyToReturn).

fluent(core_notReadyToReturn,pos_defined).
state(core_notReadyToReturn).

% Situation Names

fluent(core_nothingOfConcern,pos_defined).
situationName(core_nothingOfConcern).

fluent(core_assumedInfectiousWithDisease,pos_defined).
situationName(core_assumedInfectiousWithDisease).

fluent(core_atHighRiskIfInfectedWithDisease,pos_defined).
situationName(core_atHighRiskIfInfectedWithDisease).

fluent(core_missingInformation,pos_defined).
situationName(core_missingInformation).

% core_nothingOfConcern is a feature to report the user's progress.
feature(core_nothingOfConcern,(core_nothingOfConcern,na),core_nothingOfConcern).

% For preference order.
cost(core_atHighRiskIfInfectedWithDisease,15).
cost(core_missingInformation,10).
cost(core_assumedInfectiousWithDisease,5).

% Laws

ifThen(
    % If
    pos(core_assumedInfectiousWithDisease),
    % then
    pos(core_notReadyToReturn)).

ifThen(
    % If
    pos(core_atHighRiskIfInfectedWithDisease),
    % then
    pos(core_notReadyToReturn)).

ifThen(
    % If
    pos(core_missingInformation),
    % then
    pos(core_notReadyToReturn)).

% We defined ready to return / nothing of concern in terms of not being not
% ready to return.
ifThen(
    % If
    neg(core_notReadyToReturn),
    % then
    pos(core_readyToReturn)).

ifThen(
    % If
    neg(core_notReadyToReturn),
    % then
    pos(core_nothingOfConcern)).


% core_extensions.lp adds laws that infer the variables in core.lp. The body
% conjuncts of these laws are extension points that can be used by other modules.



% Define the infectious probabilities.
infectiousProbabilityLevel(low).
infectiousProbabilityLevel(med).
infectiousProbabilityLevel(high).

% Variables

% Track if some survey-derived property on the user has become unknown.
fluent(coreExt_userVariableBecameUnknown,pos_defined).

% The subject may be cleared whenever anything "bad" is observed.
fluent(coreExt_mayBeCleared,pos_defined).

% Is clearance received after an assumed infectious event?
fluent(coreExt_receivedClearanceAfterAssumedInfectious,pos_defined).

% Situation Names

fluent(coreExt_cleared,pos_defined).
situationName(coreExt_cleared).
child(core_nothingOfConcern,coreExt_cleared).
cost(coreExt_cleared,5).

fluent(coreExt_assumedInfectiousWithDiseaseAwaitingClearance,pos_defined).
situationName(coreExt_assumedInfectiousWithDiseaseAwaitingClearance).
child(core_assumedInfectiousWithDisease,coreExt_assumedInfectiousWithDiseaseAwaitingClearance).
cost(coreExt_assumedInfectiousWithDiseaseAwaitingClearance,5).

% Laws

% Only the guidance for the highest probability of assumed infection is needed.

ifsThen(
    % If
    (
        pos(coreExt_assumedInfectiousWithProb(low)),
        neg(coreExt_assumedInfectiousWithProb(med)),
        neg(coreExt_assumedInfectiousWithProb(high))
    ),
    % then
    pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))).

ifsThen(
    % If
    (
        pos(coreExt_assumedInfectiousWithProb(med)),
        neg(coreExt_assumedInfectiousWithProb(high))
    ),
    % then
    pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(med))).

ifThen(
    % If
    pos(coreExt_assumedInfectiousWithProb(high)),
    % then
    pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(high))).

% ASP Helpers.

% The subject is assumed infectious at some probability level. These helpers
% define a level.

% The subject is assumed infectious inertially.
fluent(coreExt_assumedInfectiousWithProb(L),inertial) :- 
    infectiousProbabilityLevel(L).

cwa_at_0(coreExt_assumedInfectiousWithProb(L)) :- 
    infectiousProbabilityLevel(L).

% Once assumed infectious, a guidance must be completed to no longer be assumed
% infectious.
fluent(coreExt_needsGuidanceForAssumedInfectiousWithProb(L),pos_defined) :- 
    infectiousProbabilityLevel(L).

% Is the guidance incomplete at this probability level?
fluent(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(L),pos_defined) :-
    infectiousProbabilityLevel(L).

% Report incomplete guidance.
feature(
    coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(L),
    (coreExt_assumedInfectiousWithProb(L),na),
    coreExt_assumedInfectiousWithProb(L)) :-
    infectiousProbabilityLevel(L).

% Request that the UI show that guidance is needed.
fluent(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(L))),pos_defined) :- 
    infectiousProbabilityLevel(L).

% Is clearance needed after an assumed infectious event?
fluent(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(L),pos_defined) :- 
    infectiousProbabilityLevel(L).

% If the subject is assumed infectious with any probability then they are
% assumed infectious.
ifThen(
    % If
    pos(coreExt_assumedInfectiousWithProb(L)),
    % then
    pos(core_assumedInfectiousWithDisease)) :- 
    infectiousProbabilityLevel(L).

% If the subject was assumed infectious and the guidance is complete and
% clearance is needed and received then normally the subject is no longer
% assumed infectious at this probability level. Exceptions include receiving new
% observations that result in the user being assumed infectious.
normallyIfsThen(
    % If
    (
        prev_pos(coreExt_assumedInfectiousWithProb(L)),
        neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(L)),
        pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(L)),
        pos(coreExt_receivedClearanceAfterAssumedInfectious)
    ),
    % Then
    neg(coreExt_assumedInfectiousWithProb(L))) :- 
    infectiousProbabilityLevel(L).

% If the subject was assumed infectious and the guidance is complete and
% clearance is not needed then normally the subject is no longer assumed
% infectious at this probability level. Exceptions include receiving new
% observations that result in the user being assumed infectious.
normallyIfsThen(
    % If
    (
        prev_pos(coreExt_assumedInfectiousWithProb(L)),
        neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(L)),
        neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(L))
    ),
    % Then
    neg(coreExt_assumedInfectiousWithProb(L))) :- 
    infectiousProbabilityLevel(L).

% If the subject is cleared by, say, HR, then the guidance is completed.
ifThen(
    % If
    pos(coreExt_cleared),
    % Then
    neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(L))) :- 
    infectiousProbabilityLevel(L).

% If guidance is needed then request that the UI show this.
ifThen(
    % If
    pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(L)),
    % Then
    pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(L))))) :- 
    infectiousProbabilityLevel(L).

% If clearance is needed then the situation is set.
ifsThen(
    % If
    (
        pos(coreExt_assumedInfectiousWithProb(L)),
        neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(L)),
        pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(L))
    ),
    % Then
    pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)) :- 
    infectiousProbabilityLevel(L).

#const coreExt_cleared_duration = 86400.
% There are two surveys - one taken when not assumed infectious and one
% otherwise.

% Variables

% Does either survey report any symptoms?
fluent(symptomsSurvey_surveyReportsSymptoms,pos_defined).

% The following are input from the non-infectious survey.

fluent(symptomsSurvey_fever,defined).
observable(symptomsSurvey_fever).

fluent(symptomsSurvey_soreThroat,defined).
observable(symptomsSurvey_soreThroat).

fluent(symptomsSurvey_cough,defined).
observable(symptomsSurvey_cough).

fluent(symptomsSurvey_lossOfSmell,defined).
observable(symptomsSurvey_lossOfSmell).

fluent(symptomsSurvey_difficultyBreathing,defined).
observable(symptomsSurvey_difficultyBreathing).

fluent(symptomsSurvey_nausea,defined).
observable(symptomsSurvey_nausea).

fluent(symptomsSurvey_diarrhea,defined).
observable(symptomsSurvey_diarrhea).

fluent(symptomsSurvey_vomiting,defined).
observable(symptomsSurvey_vomiting).

fluent(symptomsSurvey_headache,defined).
observable(symptomsSurvey_headache).

fluent(symptomsSurvey_fatigue,defined).
observable(symptomsSurvey_fatigue).

fluent(symptomsSurvey_muscleAches,defined).
observable(symptomsSurvey_muscleAches).

fluent(symptomsSurvey_fluSymptoms,defined).
observable(symptomsSurvey_fluSymptoms).

fluent(symptomsSurvey_unusualBruising,defined).
observable(symptomsSurvey_unusualBruising).

% The following are input from the infectious symptoms survey.

fluent(symptomsWhileSickSurvey_fever,defined).
observable(symptomsWhileSickSurvey_fever).

fluent(symptomsWhileSickSurvey_improvingSymptoms,defined).
observable(symptomsWhileSickSurvey_improvingSymptoms).

% Create an action in the Compliance Portal to reset the survey if it reports
% something bad. TODO Is one external action sufficient for both surveys?
fluent(cpreq(reset(symptomsSurvey_symptomsSurvey)),defined).
isRelevantOnlyIfNonCompliant(reset(symptomsSurvey_symptomsSurvey)).
isRelevantInTheFuture(reset(symptomsSurvey_symptomsSurvey)).
    
% Laws

% Add rules to show the surveys.
regulateShowingOfSurveys(
    symptomsSurvey_symptomsSurvey,
    symptomsSurvey_symptomsWhileSickSurvey,
    symptomsSurvey_symptomsSurveyCompleted,
    symptomsSurvey_symptomsWhileSickSurveyCompleted,
    missing_some(symptoms_symptomObs)
).

% Each symptom on the non-infectious survey triggers the report of symptoms.
ifThen(
    % If
    pos(symptomsSurvey_fever),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_soreThroat),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_cough),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_lossOfSmell),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_difficultyBreathing),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_nausea),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_diarrhea),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_vomiting),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_headache),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_fatigue),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_muscleAches),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_fluSymptoms),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    pos(symptomsSurvey_unusualBruising),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

% Each symptom on the infectious survey triggers the report of symptoms.
ifThen(
    % If
    pos(symptomsWhileSickSurvey_fever),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

ifThen(
    % If
    neg(symptomsWhileSickSurvey_improvingSymptoms),
    % Then
    pos(symptomsSurvey_surveyReportsSymptoms)).

% Interface with the symptoms module:

% If the survey reports symptoms then symptoms were reported.
ifThenFor(
    % If
    pos(symptomsSurvey_surveyReportsSymptoms),
    % Then
    pos(symptoms_symptomaticPos),
    symptoms_symptomsReportedDuration).

% If fever was reported on the non-infectious survey then the subject is
% feverish.
ifThenFor(
    % If
    pos(symptomsSurvey_fever),
    % Then
    pos(symptoms_feverishPos),
    symptoms_symptomsReportedDuration).

% If fever was reported on the infectious survey then the subject is feverish.
ifThenFor(
    % If
    pos(symptomsWhileSickSurvey_fever),
    % Then
    pos(symptoms_feverishPos),
    symptoms_symptomsReportedDuration).

% If the survey reports symptoms then allow it to be reset.
ifThen(
    % If
    pos(symptomsSurvey_surveyReportsSymptoms),
    % then
    pos(cpreq(reset(symptomsSurvey_symptomsSurvey)))).

% The temperature checkpoint module.

% Variables

% Was the checkpoint visited?
fluent(tempCheck_checkpointVisited,inertial).
cwa_at_0(tempCheck_checkpointVisited).
observable(tempCheck_checkpointVisited).

% Was a fever measured?
fluent(tempCheck_fever,defined).
observable(tempCheck_fever).

% Has the subject recently had a fever measured?
fluent(tempCheck_recentlyFevered,pos_defined).
% tempCheck_recentlyFevered is a feature to report the user's progress.
feature(tempCheck_recentlyFevered,(tempCheck_fever,na),core_assumedInfectiousWithDisease).

% Situation Names

fluent(tempCheck_needTempCheck,pos_defined).
situationName(tempCheck_needTempCheck).
child(symptoms_needsSymptomsReport,tempCheck_needTempCheck).
cost(tempCheck_needTempCheck,5).

% Actions

fluent(uireq(show(tempCheck_visitCheckpoint)),neg_defined).

% Laws

% Interface with the symptoms module:

% If a fever was measured then symptoms were reported.
ifThen(
    % If
    pos(tempCheck_fever),
    % Then
    pos(symptoms_symptomaticPos)).

% If fever was measured then the subject is feverish.
ifThenFor(
    % If
    pos(tempCheck_fever),
    % Then
    pos(symptoms_feverishPos),
    symptoms_symptomsReportedDuration).
    
% If the subject had a temprature measured then they are recently fevered for some period.
ifThenFor(
    % If
    pos(tempCheck_fever),
    % Then
    pos(tempCheck_recentlyFevered),
    symptoms_symptomsReportedDuration).

% If the checkpoint is visited then do not show the checkpoint action.
ifThen(
    % If
    pos(tempCheck_checkpointVisited),
    % Then
    neg(uireq(show(tempCheck_visitCheckpoint)))).

% If user is sick then do not show the checkpoint action.
ifThen(
    % If
    pos(core_assumedInfectiousWithDisease),
    % Then
    neg(uireq(show(tempCheck_visitCheckpoint)))).

% TODO Use a cost for this preference.
ifThen(
    % If
    pos(uireq(show(symptomsSurvey_symptomsSurvey))),
    % Then
    neg(uireq(show(tempCheck_visitCheckpoint)))).

% If fever becomes unknown then the checkpoint is no longer complete.
normallyIfThen(
    % If
    pos(coreExt_userVariableBecameUnknown),
    % Then
    neg(tempCheck_checkpointVisited)).

% Coordinate with other modules on fever.

% If the survey is not completed then some symptom observations are missing.
ifThen(
    neg(tempCheck_checkpointVisited),
    pos(missing_some(symptoms_symptomObs))).


% There is one surveys - taken when not assumed infectious.

% Variables

% Does either survey report any exposure?
fluent(exposureSurvey_surveyReportsExposure,pos_defined).

% The following are input from the non-infectious survey.

fluent(exposureSurvey_closeContact_covid,defined).
observable(exposureSurvey_closeContact_covid).

fluent(exposureSurvey_intlTravel,defined).
observable(exposureSurvey_intlTravel).

fluent(exposureSurvey_closeContact_intlTravel,defined).
observable(exposureSurvey_closeContact_intlTravel).

fluent(exposureSurvey_highRiskTravel,defined).
observable(exposureSurvey_highRiskTravel).

% Create an action in the Compliance Portal to reset the survey if it reports
% exposure. TODO Is one external action sufficient for both surveys?
fluent(cpreq(reset(exposureSurvey_exposureSurvey)),defined).
isRelevantOnlyIfNonCompliant(reset(exposureSurvey_exposureSurvey)).
isRelevantInTheFuture(reset(exposureSurvey_exposureSurvey)).

% Laws

% Add rules to show the surveys.
regulateShowingOfSurveys(
    exposureSurvey_exposureSurvey,
    na,
    exposureSurvey_exposureSurveyCompleted,
    na,
    missing_some(exposure_exposureObs)
).

% Each yes answer on the survey triggers the report of exposure.
ifThen(
    % If
    pos(exposureSurvey_closeContact_covid),
    % Then
    pos(exposureSurvey_surveyReportsExposure)).

ifThen(
    % If
    pos(exposureSurvey_intlTravel),
    % Then
    pos(exposureSurvey_surveyReportsExposure)).

ifThen(
    % If
    pos(exposureSurvey_closeContact_intlTravel),
    % Then
    pos(exposureSurvey_surveyReportsExposure)).

ifThen(
    % If
    pos(exposureSurvey_highRiskTravel),
    % Then
    pos(exposureSurvey_surveyReportsExposure)).

% Interface with the exposure module:

% If any exposure was reported on the survey then the subject is
% exposed.
ifThenFor(
    % If
    pos(exposureSurvey_surveyReportsExposure),  % could be pos(exposureSurvey_closeContact_covid)
    % Then
    pos(exposure_exposedPos),
    exposure_exposureReportedDuration).

% If the survey reports exposure then allow it to be reset.
ifThen(
    % If
    pos(exposureSurvey_surveyReportsExposure),
    % then
    pos(cpreq(reset(exposureSurvey_exposureSurvey)))).

% Variables

% Is the subject in need of the required negative tests to complete the
% guidance?
fluent(testing_needsNegTests(low;med;high),pos_defined).

% Has the subject recently received a positive test result.
fluent(testing_recentlyTestedPositive,pos_defined).
% testing_recentlyTestedPositive is a feature to report the user's progress.
feature(testing_recentlyTestedPositive,(testing_posTestPos,testing_posTestNeg),core_assumedInfectiousWithDisease).

% Situation Names

fluent(testing_needsTestingReport,pos_defined).
situationName(testing_needsTestingReport).
child(core_missingInformation,testing_needsTestingReport).
cost(testing_needsTestingReport,5).

% Parameters as fluents

fluentForParam(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbLow,testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbLowParam).
fluentForParam(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbMed,testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbMedParam).
fluentForParam(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbHigh,testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbHighParam).

% Laws

inferNegativeWhenNoMissingObs(
    missing_some(testing_testingObs), 
    testing_posTestPos, 
    testing_posTestNeg, 
    testing_testReportDuration).

% A report of positive test triggers a high probability assumption of infection.
ifThen(
    % If
    pos(testing_posTestPos),
    % Then
    pos(coreExt_assumedInfectiousWithProb(high))).

% Set the situation and action.
% TODO Don't base this on pos-test.
ifsThen(
    % If
    (
        neg(testing_posTestPos),
        neg(testing_posTestNeg)
    ),
    % Then
    pos(testing_needsTestingReport)).

% If the subject has tested positive then they are recently tested positive for
% some period.
ifThenForNoExtend(
    % If
    pos(testing_posTestPos),
    % Then
    pos(testing_recentlyTestedPositive),
    testing_durationThatPosTestIsRecent).

% If anything is wrong then the subject may be cleared.
ifThen(
    pos(testing_posTestPos),
    pos(coreExt_mayBeCleared)).

% If the subject is cleared then there is nothing wrong with them.
ifThen(
    % If
    pos(coreExt_cleared),
    % Then
    neg(testing_posTestPos)).

ifThen(
    % If
    pos(coreExt_cleared),
    % Then
    pos(testing_posTestNeg)).

% If the user needs a negative test and that is part of the guidance then
% guidance is needed.
ifsThen(
    % If
    (
        pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbLowParam),
        pos(testing_needsNegTests(low))
    ),
    % Then
    pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))).

ifsThen(
    % If
    (
        pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbMedParam),
        pos(testing_needsNegTests(med))
    ),
    % Then
    pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))).

ifsThen(
    % If
    (
        pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbHighParam),
        pos(testing_needsNegTests(high))
    ),
    % Then
    pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))).


#const testing_durationThatPosTestIsRecent = 864000.
#const testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbHigh = false.
#const testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbLow = true.
#const testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbMed = true.
#const testing_minTimeBetweenNegativeTestsForAssumedInfectiousWithProbHigh = 86400.
#const testing_minTimeBetweenNegativeTestsForAssumedInfectiousWithProbLow = 86400.
#const testing_minTimeBetweenNegativeTestsForAssumedInfectiousWithProbMed = 86400.
#const testing_negativeTestsNeededForAssumedInfectiousWithProbHigh = 2.
#const testing_negativeTestsNeededForAssumedInfectiousWithProbLow = 2.
#const testing_negativeTestsNeededForAssumedInfectiousWithProbMed = 2.
#const testing_testReportDuration = 86400.
% Testing surveys for when the subject is infectious and not. This module should
% not be used in conjunction with the testing_results module.

% Variables

% Does the survey report a positive test?
fluent(testingSurvey_surveyReportsPosTest,pos_defined).

% The following are input from the testing survey.

fluent(testingSurvey_posPcrTest,defined).
observable(testingSurvey_posPcrTest).

%fluent(testingSurvey_posXYZTest,defined).
%observable(testingSurvey_posXYZTest).

% The following are input from the infectious testing survey.

fluent(testingWhileSickSurvey_receivedNegativeTests,pos_defined).
observable(testingWhileSickSurvey_receivedNegativeTests).

% Create an action in the Compliance Portal to reset the survey if it reports
% positive test. TODO Is one external action sufficient for both surveys?
fluent(cpreq(reset(testingSurvey_testingSurvey)),defined).
isRelevantOnlyIfNonCompliant(reset(testingSurvey_testingSurvey)).
isRelevantInTheFuture(reset(testingSurvey_testingSurvey)).


% Laws

% Add rules to show the surveys.
regulateShowingOfSurveys(
    testingSurvey_testingSurvey,
    testingSurvey_testingWhileSickSurvey,
    testingSurvey_testingSurveyCompleted,
    testingSurvey_testingWhileSickSurveyCompleted,
    missing_some(testing_testingObs)
).

% Each positive test on the survey triggers the report of a positive test.
ifThen(
    % If
    pos(testingSurvey_posPcrTest),
    % Then
    pos(testingSurvey_surveyReportsPosTest)).

%ifThen(
%    % If
%    pos(testingSurvey_posXYZTest),
%    % Then
%    pos(testingSurvey_surveyReportsPosTest)).

% If any positive test was reported on the survey then the subject has tested
% positive.
ifThen(
    % If
    pos(testingSurvey_surveyReportsPosTest),  % could be pos(testingSurvey_posPcrTest)
    % Then
    pos(testing_posTestPos)).

% If the survey reports a positive test then allow it to be reset.
ifThen(
    % If
    pos(testingSurvey_surveyReportsPosTest),
    % then
    pos(cpreq(reset(testingSurvey_testingSurvey)))).

% If negative tests are not reported as received then the subject needs negative
% tests.
ifThen(
    % If
    neg(testingWhileSickSurvey_receivedNegativeTests),
    % Then
    pos(testing_needsNegTests(low;med;high))).

% If negative tests are reported as received then the subject does not need
% negative tests.
ifThen(
    % If
    pos(testingWhileSickSurvey_receivedNegativeTests),
    % Then
    neg(testing_needsNegTests(low;med;high))).

% If the survey reports needing a negative test then allow it to be reset.
ifThen(
    % If
    neg(testingWhileSickSurvey_receivedNegativeTests),
    % then
    pos(cpreq(reset(testingSurvey_testingSurvey)))).

% Variables

fluent(clearance_clearanceReceived,pos_defined).
observable(clearance_clearanceReceived).

fluent(clearance_clearanceReceivedAfterAssumedInfectious,pos_defined).
observable(clearance_clearanceReceivedAfterAssumedInfectious).

% Actions

% Create an action in the Compliance Portal to clear the user if anything
% clearable is reported.
fluent(cpreq(show(clearance_mayBeCleared)),defined).
isRelevantOnlyIfNonCompliant(show(clearance_mayBeCleared)).
isRelevantInTheFuture(show(clearance_mayBeCleared)).

% Whenever the user may be cleared, they may also be denied clearance.
fluent(cpreq(show(clearance_mayBeDeniedClearance)),defined).
isRelevantOnlyIfNonCompliant(show(clearance_mayBeDeniedClearance)).
isRelevantInTheFuture(show(clearance_mayBeDeniedClearance)).

% Create an action in the Compliance Portal to clear the user after assumed
% infectious.
fluent(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious)),defined).

% Whenever the user may be cleared, they may also be denied clearance.
fluent(cpreq(show(clearance_mayBeDeniedClearanceAfterAssumedInfectious)),defined).

% Parameters as fluents

fluentForParam(clearance_cpUserCanClearBadStates,clearance_cpUserCanClearBadStatesParam).
fluentForParam(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbLow,clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbLowParam).
fluentForParam(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbMed,clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbMedParam).
fluentForParam(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbHigh,clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbHighParam).

% Laws

% Receving a clearance results in the subject being cleared for some duration.
ifThenFor(
    % If
    pos(clearance_clearanceReceived),
    % Then
    pos(coreExt_cleared),
    clearance_clearanceDuration).

% If the subject may be cleared then add an action in the CP.
ifsThen(
    % If
    (
        pos(coreExt_mayBeCleared),
        clearance_cpUserCanClearBadStatesParam
    ),
    % Then
    pos(cpreq(show(clearance_mayBeCleared)))).

% If the subject can be cleared then they can be denied clearance.
ifThen(
    % If
    pos(cpreq(show(clearance_mayBeCleared))),
    % Then
    pos(cpreq(show(clearance_mayBeDeniedClearance)))).

% Convert the parameters to module fluents.
ifThen(
    % If
    pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbLowParam),
    % Then
    pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))).

ifThen(
    % If
    pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbMedParam),
    % Then
    pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))).

ifThen(
    % If
    pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbHighParam),
    % Then
    pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))).

% If the subject needs clearance then add an action in the CP.
ifThen(
    % If
    pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance),
    % Then
    pos(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious)))).

% If the subject can be cleared then they can be denied clearance.
ifThen(
    % If
    pos(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious))),
    % Then
    pos(cpreq(show(clearance_mayBeDeniedClearanceAfterAssumedInfectious)))).

% If clearance is received then clearance is received.
ifThen(
    % If
    pos(clearance_clearanceReceivedAfterAssumedInfectious),
    % Then
    pos(coreExt_receivedClearanceAfterAssumedInfectious)).
#const clearance_clearanceDuration = 86400.
#const clearance_cpUserCanClearBadStates = false.
#const clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbHigh = true.
#const clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbLow = true.
#const clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbMed = true.
% Was the survey completed?
fluent(HealthySurveyCompleted,inertial) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).

cwa_at_0(HealthySurveyCompleted) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).

observable(HealthySurveyCompleted) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).


% Was the infectious survey completed?
fluent(SickSurveyCompleted,inertial) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.

cwa_at_0(SickSurveyCompleted) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.

observable(SickSurveyCompleted) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.


% If either survey is completed then do not show the healthy survey.
ifThen(
    % If
    pos(HealthySurveyCompleted),
    % Then
    neg(uireq(show(HealthySurvey)))) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).

ifThen(
    % If
    pos(SickSurveyCompleted),
    % Then
    neg(uireq(show(HealthySurvey)))) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.

% If the user is infectious then do not show the healthy survey.
ifThen(
    % If
    pos(core_assumedInfectiousWithDisease),
    % Then
    neg(uireq(show(HealthySurvey)))) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).

% If either survey is completed then do not show the sick survey.
ifThen(
    % If
    pos(HealthySurveyCompleted),
    % Then
    neg(uireq(show(SickSurvey)))) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).

ifThen(
    % If
    pos(SickSurveyCompleted),
    % Then
    neg(uireq(show(SickSurvey)))) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.

% If the user is not infectious then do not show the sick survey.
ifThen(
    % If
    neg(core_assumedInfectiousWithDisease),
    % Then
    neg(uireq(show(SickSurvey)))) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.

% If a user variable becomes unknown then normally the survey is no longer
% complete. The exception is that a new survey is completed at the same time
% step. Practically that shouldn't happen.
normallyIfThen(
    % If
    pos(coreExt_userVariableBecameUnknown),
    % Then
    neg(HealthySurveyCompleted)) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).

% If a user variable becomes unknown then normally the sick survey is no longer
% complete. The exception is that a new survey is completed at the same time
% step. Practically that shouldn't happen.
normallyIfThen(
    % If
    pos(coreExt_userVariableBecameUnknown),
    % Then
    neg(SickSurveyCompleted)) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.

% Coordinate with other modules.

% If survey is not completed then some observations are missing.
ifThen(
    neg(HealthySurveyCompleted),
    pos(MissingSome)) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey == na.

% If neither survey is completed then some observations are missing.
ifsThen(
    (
        neg(HealthySurveyCompleted),
        neg(SickSurveyCompleted)
    ),
    pos(MissingSome)) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.

% Actions

fluent(uireq(show(HealthySurvey)),neg_defined) :- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).

isDailyCheckup(show(HealthySurvey)):- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).
    

fluent(uireq(show(SickSurvey)),neg_defined):- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.
    
isDailyCheckup(show(SickSurvey)):- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ),
    SickSurvey != na.

% Send a message to the user to do their survey.
fluent(message(remind(HealthySurvey)),defined):- 
    regulateShowingOfSurveys(
        HealthySurvey,
        SickSurvey,
        HealthySurveyCompleted,
        SickSurveyCompleted,
        MissingSome
    ).
    




% VERSION: 8.4-incr_plus

% ** OPTIMIZATION
% ** ============
% ** This file is written for use in the iterative solver
% ** Incremental+. See the documentation on Incremental+
% ** for details.
% **
% ** To use this program with segment-based solver scanner2:
% **
% **   Alternative A:
% **    - Remove/comment out all #program directives from all programs used
% **    - Add a directive (or a corresponding command-line option):
% **		#const t=0.
% **
% **   Alternative B:
% **    - Add a directive (or a corresponding command-line option):
% **		#const t=0.
% **    - When grounding, use all of these programs: base, from(0), output
% **


% r [for n steps] if l_1,...,l_k

% s_law(s).
% head(s,r).
% duration(s,n). {optional, defaults to 0; only available for non-inertial heads}
% is_default(s) { optional, s is a default. See "support for defaults" below for requirements }
% is_no_extend(s) { optional, available only when duration is specified; a
%                   no-extend state constraint will not affect the 
% 		  time left on a fluent literal if the fluent literal already
% 		  holds and the state constraint would cause its duration
%                   to be extended. }

% body(s,l_1).
% [...]
% body(s,l_k).

% r: restricted literal expression
% l: literal expression

% restricted literal expressions:
%   pos(f): fluent f is true
%   neg(f): fluent f is false

% literal expression:
%   a restricted literal expression, or:
%   prev_pos(f): fluent f is true
%   prev_neg(f): fluent f is false


% preferences over conflicting rules
% prefer(l_1,l_2).



% % #program base.

% %
% % INPUT:
% %  report_blocked(T): report laws that are blocked at time step T
% %  report_blocked: report laws that are blocked at every time step
% %

% Automatically extend the timeline based on available observations
time(T) :- obs(X,Y,T).

% backward compatibility
rule(R) :- s_law(R).

boolean_fluent(F) :-
	fluent(F,inertial).
boolean_fluent(F) :-
	fluent(F,defined).
boolean_fluent(F) :-
	fluent(F,pos_defined).
boolean_fluent(F) :-
	fluent(F,neg_defined).

noninertial_fluent(F) :-
	boolean_fluent(F),
	not fluent(F,inertial).

fluent_of_expr(F,pos(F)) :-
	boolean_fluent(F).
fluent_of_expr(F,neg(F)) :-
	boolean_fluent(F).

abs(F,F) :- boolean_fluent(F).
abs(-F,F) :- boolean_fluent(F).
abs(O,O) :- observable(O).
abs(-O,O) :- observable(O).

% Add support for non-boolean functional fluents implicitly
% defined by observations.
% Form of observation: obs(Name,Value,T)
% Result: inertial fluent v(Name,Value)
% The fluent behaves functionally, i.e. only one value 
% is allowed at any time.
% Note: a non-boolean functional fluent is not a first-class
% citizen of the language. Rather, it is represented by
% a boolean fluent that combines name and value of the
% non-boolean functional fluent.
%
% EXAMPLE
% Given:
%  time(0). time(1). time(86401). time(86402).
%  obs(abc,5,0).
%  h(v(abc,3),86401).
% Expected:
%  h(v(abc,5),0), h(v(abc,3),86401), h(v(abc,3),86402), -h(v(abc,5),86401), -h(v(abc,5),86402)
%
fluent(v(N,V),inertial) :- obs(N,V,T), V!=true, V!=false.
h(v(N,V),T) :- obs(N,V,T).

tc(prefer(X,Y)) :- prefer(X,Y).
tc(prefer(X,Y)) :- prefer(X,Z), tc(prefer(Z,Y)).

#const t=0.
%#program from(t).
% NOTE: condition segment(_,_) can be removed if
% scanner2/segment-restricted computation is not used
%#external enabled(T) : time(T), T>=t, not segment(_,_).

%%%%% SUPPORT FOR scanner2/segment-restricted computation %%%%%
%%%%%%%%%%%%%%%% can be removed if not needed %%%%%%%%%%%%%%%%%
% assumption: no incremental grounding+solving
enabled(T) :- 
	time(T),
	segment(LOW,HIGH),
	T<=HIGH.

% Ensure that only time steps that are in-segment can yield time step requests
% assumption: no incremental grounding+solving
time(NT) :- 
	reqtime(T,NT), 
	segment(LOW,HIGH),
	LOW<=T, T<=HIGH.

%%%%% END OF SUPPORT FOR scanner2/segment-restricted computation %%%%%

% simple version of timeline
%next(T,T+1) :- time(T), time(T+1).
%  not supported -- computed statically 
% next(T',T) :-
% 	time(T),
% 	time(T'),
% 	T=#min{ S : time(S), S > T' }, enabled(T), T>=t.


% ==== SEMANTICS OF RULES ====

left(F,N,T) :-
	time(T),
	enabled(T), T>=t,
	rule(R),
	fired(R,T),
	head(R,H),
	fluent_of_expr(F,H),
	noninertial_fluent(F),
	duration(R,N),
	not is_no_extend(R).
%
% Support for no-extend state constraints
%
left(F,N,T) :-
	time(T),
	enabled(T), T>=t,
	rule(R),
	fired(R,T),
	head(R,H),
	fluent_of_expr(F,H),
	noninertial_fluent(F),
	duration(R,N),
	is_no_extend(R),
	not would_extend(H,T).
%
would_extend(pos(F),T') :-
	noninertial_fluent(F),
	next(T,T'),
	enabled(T'), T'>=t,
	h(F,T),
	left(F,V,T),
	E=T'-T, V-E>=0.	% elapsed time
would_extend(neg(F),T') :-
	noninertial_fluent(F),
	next(T,T'),
	enabled(T'), T'>=t,
	-h(F,T),
	left(F,V,T),
	E=T'-T, V-E>=0.	% elapsed time

% make sure to add suitable time points
newtime(T) :-
	newtime2(T',T),
	enabled(T'), T'>=t,
	segment(A,B).
	
newtime2(T',T) :-	% officially request the addition of a time point only if it does not already exist
	reqtime(T',T),
	enabled(T'), T'>=t,
	not time(T).

reqtime(T,(T+N;T+N+1)) :-
	time(T), enabled(T), T>=t,
	rule(R),
	fired(R,T),
	head(R,H),
	fluent_of_expr(F,H),
	noninertial_fluent(F),
	duration(R,N),
	not is_no_extend(R).
%
% Support for no-extend state constraints
%
reqtime(T,(T+N;T+N+1)) :-
	time(T), enabled(T), T>=t,
	rule(R),
	fired(R,T),
	head(R,H),
	fluent_of_expr(F,H),
	noninertial_fluent(F),
	duration(R,N),
	is_no_extend(R),
	not would_extend(H,T).

left(F,0,T) :-
	time(T), enabled(T), T>=t,
	rule(R),
	fired(R,T),
	head(R,H),
	fluent_of_expr(F,H),
	noninertial_fluent(F),
	not has_duration(R).

has_duration(R) :-
	duration(R,D).

h'(H,T) :-
	time(T), enabled(T), T>=t,
	rule(R),
	fired(R,T),
	head(R,H).

% At time T, B contributes to triggering rule R and concluding H
proves(H,R,B,T) :-
	time(T), enabled(T), T>=t,
	rule(R),
	fired(R,T),
	head(R,H),
	body(R,B).

% Rule R is fired at time T
fired(R,T) :-
	time(T), enabled(T), T>=t,
	rule(R),
	body_satisfied(R,T),
	not rule_blocked(R,T).

% Support for defaults
%
% GENERAL STATEMENTS
% * At any time step and under any combination of conditions,
%   at most one default can be applicable.
% * Additionally, a default cannot be applied if an observation
%   about the same fluent exists.
% The two statements could be combined into a single one, e.g.
% "A default cannot be applied if the complement of its head
% holds at the same time".
% However, formalizing this statement requires prioritizing it
% over inertia, defined fluents behaving inertially, and defined
% fluents with default values. Implementing such a prioritization
% is somewhat cumbersome compared to the rules for the two
% statements above. Obviously, we lose elaboration tolerance
% in case we introduce new ways of affecting a fluent's truth
% value other than state constraints and observations.
%
% TODO: generalize the two statements. See above comment.
%
rule_blocked(R1,T) :-
	time(T), enabled(T), T>=t,
	rule(R1), rule(R2), R1!=R2,
	is_default(R1),
	head(R1,E1), head(R2,E2),
	fluent_of_expr(F,E1), fluent_of_expr(F,E2),
	E1 != E2,
	body_satisfied(R2,T).
rule_blocked(R,T) :-
	time(T), enabled(T), T>=t,
	rule(R),
	is_default(R),
	head(R,E),
	fluent_of_expr(F,E),
	obs(F,W,T).
%
rule_blocked(R2,T) :-
	time(T), enabled(T), T>=t,
	rule(R1), rule(R2), R1!=R2,
	head(R1,E1), head(R2,E2),
	body_satisfied(R1,T), body_satisfied(R2,T),
	tc(prefer(E1,E2)).

%  no support for #count -- replaced by other rules
% body_satisfied(R,T) :-
% 	time(T), enabled(T), T>=t,
% 	rule(R),
% 	#count{ F : body(R,pos(F)), boolean_fluent(F) }=PB,
% 	#count{ F : body(R,pos(F)), boolean_fluent(F), h(F,T) }=PB,
% 	#count{ F : body(R,neg(F)), boolean_fluent(F) }=NB,
% 	#count{ F : body(R,neg(F)), boolean_fluent(F), -h(F,T) }=NB,
% 	#count{ F : body(R,prev_pos(F)), boolean_fluent(F) }=PPB,
% 	#count{ F : body(R,prev_pos(F)), boolean_fluent(F), next(T',T), h(F,T') }=PPB,
% 	#count{ F : body(R,prev_neg(F)), boolean_fluent(F) }=NPB,
% 	#count{ F : body(R,prev_neg(F)), boolean_fluent(F), next(T',T), -h(F,T') }=NPB,
% % [MB] introducing "expired" condition
% 	#count{ F : body(R,expired(F)), noninertial_fluent(F) }=EB,
% 	#count{ F : body(R,expired(F)), noninertial_fluent(F), next(T',T), left(F,0,T'), truth_set_by_inertia(F,T') }=EB.
% % end [MB]
% % obsolete -- removed
% %	#count{ F : body(R,val(F,V)), fluent(F,timed) }=VB,
% %	#count{ F : body(R,val(F,V)), fluent(F,timed), h(val(F,V),T) }=VB,
% %	#count{ F : body(R,diff(F,V)), fluent(F,timed) }=DB,
% %	#count{ F : body(R,diff(F,V)), fluent(F,timed), h(val(F,V'),T), V!=V' }=DB.


body_satisfied(R,T) :-
	body_satisfied_from(R,1,T).

body_satisfied_from(R,N,T) :-
	body_size(R,S), N <= S,
	body_satisfied_at(R,N,T),
	body_satisfied_from(R,N+1,T).
body_satisfied_from(R,N,T) :-
	time(T),
	newbody(R,N,nil).
body_satisfied_at(R,N,T) :-
	newbody(R,N,pos(F)), boolean_fluent(F), h(F,T).
body_satisfied_at(R,N,T) :-
	newbody(R,N,neg(F)), boolean_fluent(F), -h(F,T).
body_satisfied_at(R,N,T) :-
	newbody(R,N,prev_pos(F)), boolean_fluent(F), next(T',T), h(F,T').
body_satisfied_at(R,N,T) :-
	newbody(R,N,prev_neg(F)), boolean_fluent(F), next(T',T), -h(F,T').
body_satisfied_at(R,N,T) :-
	newbody(R,N,expired(F)), noninertial_fluent(F), next(T',T), left(F,0,T'), truth_set_by_inertia(F,T').


report_blocked(T) :-
	report_blocked,
	time(T), enabled(T), T>=t.

% Rule R is blocked because B is not satisfied
blocked(R,pos(F),T) :-
	time(T), enabled(T), T>=t,
	report_blocked(T),
	rule(R),
	body(R,pos(F)),
	boolean_fluent(F),
	not h(F,T).
%
blocked(R,neg(F),T) :-
	time(T), enabled(T), T>=t,
	report_blocked(T),
	rule(R),
	body(R,neg(F)),
	boolean_fluent(F),
	not -h(F,T).
%
blocked(R,val(F,V),T) :-
	time(T), enabled(T), T>=t,
	report_blocked(T),
	rule(R),
	body(R,val(F,V)),
	fluent(F,timed),
	not h(val(F,V),T).
%
blocked(R,diff(F,V),T) :-
	time(T), enabled(T), T>=t,
	report_blocked(T),
	rule(R),
	body(R,diff(F,V)),
	fluent(F,timed),
	h(val(F,V),T).
%
% obsolete -- removed
%blocked(R,diff(F,V),T) :-
%	time(T), enabled(T), T>=t,
%	report_blocked(T),
%	rule(R),
%	body(R,diff(F,V)),
%	fluent(F,timed),
%	not h(val(F,_),T).

h(F,T) :-
	boolean_fluent(F),
	h'(pos(F),T),
	time(T), enabled(T), T>=t.
-h(F,T) :-
	boolean_fluent(F),
	h'(neg(F),T),
	time(T), enabled(T), T>=t.

h(val(F,V),T) :-
	fluent(F,timed),
	h'(val(F,V),T),
	time(T), enabled(T), T>=t.


% ==== SEMANTICS OF TIMED FLUENTS ====
% They monotonically decrease by 1 at every state transition
% until reaching 0, unless forcefully prevented from doing so.
% After reaching 0, they have no value until they are reset.

h(val(F,V-E),T') :-
	fluent(F,timed),
	next(T,T'),
	enabled(T'), T'>=t,
	E=T'-T, V-E>=0,	% elapsed time
	h(val(F,V),T), V>0,
	not willHaveOtherValue(F,T),
	not -h(val(F,V-E),T').

willHaveOtherValue(F,T) :-
	fluent(F,timed),
	next(T,T'),
	enabled(T'), T'>=t,
	E=T'-T, V-E>=0,	% elapsed time
	h(val(F,V),T),
	h(val(F,V'),T'),
	V'!=V-E.

%h(val(F,0),T+1) :-
%	fluent(F,timed),
%	time(T), time(T+1),
%	enabled(T+1), T+1>=t,
%	h(val(F,0),T),
%	not willHaveOtherValueThan0(F,T).
%	%,
%	%not -h(val(F,0),T+1).

%h(val(F,0),0) :-
%	enabled(0), 0>=t,
%	fluent(F,timed),
%	not willHaveOtherValueThan0(F,0).
%	%,
%	%not -h(val(F,0),0).

%willHaveOtherValueThan0(F,T) :-
%	fluent(F,timed),
%	time(T),
%	enabled(T), T>=t,
%	h(val(F,V),T),
%	V!=0.


% ==== SEMANTICS OF DURATIVE STATE CONSTRAINTS ====
left(F,V-E,T') :-
	noninertial_fluent(F),
	next(T,T'),
	enabled(T'), T'>=t,
	E=T'-T, V-E>=0,	% elapsed time
	left(F,V,T), V>0,
	not willHaveOtherLeftValue(F,T').

willHaveOtherLeftValue(F,T') :-
	noninertial_fluent(F),
	next(T,T'),
	enabled(T'), T'>=t,
	left(F,V,T),
	left(F,V',T'),
	E=T'-T, V-E>=0,	% elapsed time
	V'!=V-E.

left(F,0,T') :-
	noninertial_fluent(F),
	next(T,T'),
	enabled(T'), T'>=t,
	left(F,0,T),
	not willHaveOtherLeftValueThan0(F,T').

willHaveOtherLeftValueThan0(F,T) :-
	noninertial_fluent(F),
	time(T), enabled(T), T>=t,
	left(F,V,T),
	V!=0.



% ==== SEMANTICS OF INERTIAL FLUENTS ====

% It is possible to apply CWA at step 0
% to inertial fluents.
-h(F,0) :-
	enabled(0), 0>=t,
	fluent(F,inertial),
	cwa_at_0(F),
	not h(F,0).

h(F,T') :-
	fluent(F,inertial),
	next(T,T'),
	enabled(T'), T'>=t,
	h(F,T),
	not -h(F,T').

-h(F,T') :-
	fluent(F,inertial),
	next(T,T'),
	enabled(T'), T'>=t,
	-h(F,T),
	not h(F,T').


% ---- SEMANTICS of NON-BOOLEAN FUNCTIONAL FLUENTS ----
%
% Axiom on the functional nature of the non-boolean functional
% fluents
%
% If a non-boolean functional fluent has value V, then it 
% does not have any other value V', where V' is any value 
% different from V that the fluent had at the previous 
% time step.
% This statement does not yield complete negative
% knowledge about the value of N, but it strikes a balance
% between blocking inertia and allowing for incremental
% solving, while removing the need to explicitly state the
% domain of the non-boolean functional fluent.
% If we change the statement to "...that the fluent had at
% any other time step", incremental solving would no longer
% be possible.
% What would work is to say "...that the fluent had at
% any previous time step", but that modification does not
% yield all negative knowledge and at the same time causes
% the grounding to grow.
-h(v(N,V'),T) :-
	next(T',T),
	enabled(T), T>=t,
	h(v(N,V),T),
	h(v(N,V'),T'),
	V!=V'.


% ==== SEMANTICS OF DEFINED FLUENTS ====

%%%%%%%%%%% >>>>>>>>>>>>>> timed spans
behaves_inertially(F,T) :-
	noninertial_fluent(F),
	time(T), enabled(T), T>=t,
	left(F,V,T), V>0.

%-behaves_inertially(F,T) :-
%	noninertial_fluent(F),
%	time(T), enabled(T), T>=t,
%	not behaves_inertially(F,T).

truth_set_by_inertia(F,T') :-
	noninertial_fluent(F),
	next(T,T'),
	enabled(T'), T'>=t,
	behaves_inertially(F,T).

% if F behaves inertially in T, it means that the next time step
% will have the truth value of F propagated by inertia
h(F,T') :-
	noninertial_fluent(F),
	next(T,T'),
	enabled(T'), T'>=t,
	%behaves_inertially(F,T),
	truth_set_by_inertia(F,T'),
	h(F,T),
	not -h(F,T').

-h(F,T') :-
	noninertial_fluent(F),
	next(T,T'),
	enabled(T'), T'>=t,
	%behaves_inertially(F,T),
	truth_set_by_inertia(F,T'),
	-h(F,T),
	not h(F,T').
%%%%%%%%%%% <<<<<<<<<<<<<< timed spans

-h(F,T) :-
	fluent(F,pos_defined),
	time(T), enabled(T), T>=t,
	%-behaves_inertially(F,T),
	not truth_set_by_inertia(F,T),
	not h(F,T).

h(F,T) :-
	fluent(F,neg_defined),
	time(T), enabled(T), T>=t,
	%-behaves_inertially(F,T),
	not truth_set_by_inertia(F,T),
	not -h(F,T).

% No need for rules for (non-pos, non-neg) defined fluents
% that do not behave inertially.
% They simply default to unknown.



% SEMANTICS OF BOOLEAN OBSERVATIONS
%
h(F,T) :- observable(F), time(T), obs(F,true,T), enabled(T), T>=t.
-h(F,T) :- observable(F), time(T), obs(F,false,T), enabled(T), T>=t.
%%%%%%%%-h(F,T) :- observable(F), cwa(F), time(T), not obs(F,true,T), enabled(T), T>=t.



% ==== SEMANTICS OF OBSERVATIONS OVER SPANS OF TIME ====

% OBSERVATIONS:
% obs(F,sometime_in_past(LEN),T)
% obs(F,never_in_past(LEN),T)
%   RESTRICTION: F must be a defined fluent
%   RESTRICTION: negated fluents are not allowed

h_span(F,T-LEN+1,T) :-
	boolean_fluent(F),
	time(T), enabled(T), T>=t,
	obs(F,sometime_in_past(LEN),T).
-h_span(F,T-LEN+1,T) :-
	boolean_fluent(F),
	time(T), enabled(T), T>=t,
	obs(F,never_in_past(LEN),T).

% TODO: these rules must be revised for the use in the from(t) program
time(L..U) :-	% dynamically expand timeline based on observations
	fluent(F,defined),
	h_span(FL,L,U),
	abs(FL,F).
-possible_occurrence(F,T) :-
	boolean_fluent(F),
	-h_span(F,L,U),
	enabled(T), T>=t,
	time(T), T>=L, T<=U.
possible_occurrence(F,T) :-
	boolean_fluent(F),
	h_span(F,L,U),
	time(T), T>=L, T<=U,
	enabled(T), T>=t,
	not -possible_occurrence(F,T).

h(F,T) :-
	boolean_fluent(F),
	time(T), enabled(T), T>=t,
	possible_occurrence(F,T).

-h(F,T) :-
	boolean_fluent(F),
	time(T), enabled(T), T>=t,
	-possible_occurrence(F,T).

% TO-DO: should we somehow account for possible conflicts with
%        state constraints?
%        For now, we can avoid it under the assumption that
%        observable fluents cannot be defined by state constraints.
left(F,0,T) :-
	noninertial_fluent(F),
	time(T), enabled(T), T>=t,
	possible_occurrence(F,T).

left(F,0,T) :-
	noninertial_fluent(F),
	time(T), enabled(T), T>=t,
	-possible_occurrence(F,T).

% Evaluation of consistency and likelihood of "span fluents"
% Input: confirmed(F,L,U): observation that F held between L and U has been confirmed by the user/HR
% Output: warning(F,L,U,T): observation that F held between L and U boils down to the fact that the observation must have held exactly and only at T
%         inconsistent(F,L,U): observation that F held between L and U is inconsistent with other information. Specifically, F cannot have held between L and U

% obsolete -- removed
%left_for(F,L,U,N) :-
%	boolean_fluent(F),
%	h_span(F,L,U),
%	N=#count{ T : time(T), T>=L, T<=U, possible_occurrence(F,T) }.

span_obs(obs(F,sometime_in_past(LEN),T),F,T-LEN+1,T) :- obs(F,sometime_in_past(LEN),T), time(T), enabled(T), T>=t.
span_obs(obs(F,never_in_past(LEN),T),F,T-LEN+1,T) :- obs(F,never_in_past(LEN),T), time(T), enabled(T), T>=t.
needs_revision(O,L,U,TYPE) :-
	questionnaireTime(T),
	time(T), enabled(T), T>=t,
	problematic(F,L,U,TYPE),
	span_obs(O,F,L',U'),
	L<=L', L'<=U.
needs_revision(O,L,U,TYPE) :-
	questionnaireTime(T),
	time(T), enabled(T), T>=t,
	problematic(O,L,U,TYPE),
	span_obs(O,F,L',U'),
	L'<=L, L<=U'.

problematic(F,L,U,single_value(F,T)) :-
	left_for(F,L,U,1),
	possible_occurrence(F,T),
	time(T), T>=L, T<=U,
	enabled(T), T>=t,
	not confirmed(F,L,U).
problematic(F,L,U,inconsistent(F)) :-
	left_for(F,L,U,0),
	not confirmed(F,L,U).


% #program base.

% #program base.

%-------- Define features.

% Features are fluents whose value is used to describe the current state of the
% user. A fact like feature(F,(InitializedBy1,InitializedBy2),ConditionedBy)
% will indicate that Fluent is a feature that should begin to be reported after
% one of the InitializedBy fluents becomes true. And then it will be reported
% whenever it is true and ConditionedBy is true. This allows us to not report
% "recently symptomatic" until such time as we have information about the
% subject's symptoms. And it also lets us report this only when the user is
% assumed infectious.

% The feature fluent is positively defined.
fluent(feature(F),pos_defined) :- 
  feature(F,(InitializedBy1,InitializedBy2),ConditionedBy).

% An inertial fluent tracks if it is initialized.
fluent(initialized(feature(F)),inertial) :- 
  feature(F,(InitializedBy1,InitializedBy2),ConditionedBy).

cwa_at_0(initialized(feature(F))) :- 
  feature(F,(InitializedBy1,InitializedBy2),ConditionedBy).

% The InitializedBy fluents mark it as initialized.
ifThen(
  % If
  pos(InitializedBy1),
  % Then
  pos(initialized(feature(F)))) :- 
  feature(F,(InitializedBy1,InitializedBy2),ConditionedBy),
  InitializedBy1 != na.

ifThen(
  % If
  pos(InitializedBy2),
  % Then
  pos(initialized(feature(F)))) :- 
  feature(F,(InitializedBy1,InitializedBy2),ConditionedBy),
  InitializedBy2 != na.

% Once initialized, the value of the fluent is based on ConditionedBy.
ifsThen(
  % If
  (
    pos(initialized(feature(F))),
    pos(F),
    pos(ConditionedBy)
  ),
  % Then
  pos(feature(F))) :- 
  feature(F,(InitializedBy1,InitializedBy2),ConditionedBy).

%-------- Turn boolean parameters into fluents.

fluent(F,inertial) :- fluentForParam(P,F).
observable(F) :- fluentForParam(P,F).
obs(F,P,0) :- fluentForParam(P,F).

%-------- Coordinating variables among modules.

% For coordination of modules: P and N represent the truth and falsity of an
% observable attribute like symptomatic or tested positive. They are positively
% defined fluents, so that, if neither P or N is true then that means that the 
% truth of the attribute is unknown. 
% The attribute might be observed in mulitple ways. If one of those ways is 
% outstanding then the fluent M will be true. 
% But if no observation is missing (i.e., M is false) and the subject
% does not have the attribute (P is false) and the previously the subject did
% not have the attribute (N is previously false) then the subject is known to
% not have the attribute (N is true) for a duration D.
ifsThenForNoExtend((neg(M),neg(P)),pos(N),D) :-
    inferNegativeWhenNoMissingObs(M,P,N,D), D>0.

ifsThen((neg(M),neg(P),prev_neg(N)),pos(N)) :-
    inferNegativeWhenNoMissingObs(M,P,N,D), D==0.

ifThen(pos(P),neg(N)) :- inferNegativeWhenNoMissingObs(M,P,N,D).
ifThen(pos(N),neg(P)) :- inferNegativeWhenNoMissingObs(M,P,N,D).

% M is a pos defined fluent.
fluent(M,pos_defined) :- inferNegativeWhenNoMissingObs(M,P,N,D).

% P is a pos defined fluent.
fluent(P,pos_defined) :- inferNegativeWhenNoMissingObs(M,P,N,D).

% N is a pos defined fluent.
fluent(N,pos_defined) :- inferNegativeWhenNoMissingObs(M,P,N,D).

% The event of an attribute's truth becoming unknown infers a common variable. 
ifsThen((prev_pos(P),neg(P),neg(N)),pos(coreExt_userVariableBecameUnknown)) :-
    inferNegativeWhenNoMissingObs(M,P,N,D).

ifsThen((expired(N),neg(P)),pos(coreExt_userVariableBecameUnknown)) :-
    inferNegativeWhenNoMissingObs(M,P,N,D).

% If any attribute's truth becomes unknown then all observable attributes become
% unknown.
normallyIfThen(pos(coreExt_userVariableBecameUnknown),neg(P)) :-
    inferNegativeWhenNoMissingObs(M,P,N,D).
    
normallyIfThen(pos(coreExt_userVariableBecameUnknown),neg(N)) :-
    inferNegativeWhenNoMissingObs(M,P,N,D).
    
%-------- Script extensions

prefer(S1,S2) :-
  script(S1),
  script(S2),
  has_goal(S1,G),
  has_goal(S2,G),
  cost(S1,C1),
  cost(S2,C2),
  C1<C2.

fluent(inertial_req_start(S),inertial) :-
  script(S),
  has_inertial_req_start(S).

ifThen(pos(inertial_req_start(S)),pos(req_start(S))) :-
  script(S),
  has_inertial_req_start(S).

%#program from(t).

% not needed -- removed
%executed(A,I,T1) :-
%  senses(A,F),
%  uireq(execute(A,I,T2)),
%  #count{ executed(A,I,T3) : T3>T2, T3<T1, time(T3) }=0,
%  obs(F,W,T1),
%  enabled(T1), T1>=t,
%  T2<T1.

-h(inertial_req_start(S),T) :-
  script(S),
  has_inertial_req_start(S),
  has_goal(S,G),
  enabled(T), T>=t,
  achieved(G,T).

-h(inertial_req_start(S),T) :-
  script(S),
  has_inertial_req_start(S),
  has_goal(S,G),
  enabled(T), T>=t,
  failed(G,T).

%-------- Situation hierarchy.

% #program base.

% Among sibling situations, prefer the least expensive.
prefer(pos(S1),pos(S2)) :-
  situationName(S1),
  situationName(S2),
  situationName(S3),
  child(S3,S1),
  child(S3,S2),
  cost(S1,C1),
  cost(S2,C2),
  C1<C2.

% Among parentless sibling situations, prefer the least expensive.
prefer(pos(S1),pos(S2)) :-
  situationName(S1),
  situationName(S2),
  not has_child_for(S1),
  not has_child_for(S2),
  cost(S1,C1),
  cost(S2,C2),
  C1<C2.

has_child_for(S) :-
	child(S).

% If a child situation is true then so is its parent.
ifThen(pos(C),pos(P)) :-
  situationName(C),
  situationName(P),
  child(P,C).
  
%#program output.   % [MB]

%  not needed -- removed
% % The most specific situation is the one that holds and has no children or
% % brothers that hold...
% mostSpecificSituation(S,T) :-
%   situationName(S),
%   h(S,T),
%   #count{C : child(S,C), h(C,T)} = 0,
%   #count{B : child(P,B), child(P,S), h(B,T), B!=S} = 0.

% % Or holds and has multiple children that hold and no brothers that hold.
% mostSpecificSituation(S,T) :-
%   situationName(S),
%   h(S,T),
%   #count{C : child(S,C), h(C,T)} > 1,
%   #count{B : child(P,B), child(P,S), h(B,T), B!=S} = 0.


%-------- Policy independent rules for the UI.

% Helpful compliance inference. TODO: Put in semantics?
compliant(T) :-
  compliantState(S),
  h(S,T),
  time(T).
-compliant(T) :-
  not compliant(T),
  time(T).

% Actions are relevant when they occur.
% TODO This is an output inference.
action(A,T) :- h(uireq(A),T).
% Script actions have an instance associated.
% TODO Ideally, the instance is associated with the observation.
action(A,T) :- uireq(execute(A,I,T)).
isRelevant(A,T) :-
  action(A,T),
  now(T).

% External actions.
% TODO This is an output inference.
externalAction(A,T) :- h(cpreq(A),T).

% For external actions that are relevant in the future and only if the status is not compliant.
% TODO This is an output inference.
isRelevant(A,T1) :-
  externalAction(A,T1),
  isRelevantOnlyIfNonCompliant(A),
  -compliant(T2),
  isRelevantInTheFuture(A),
  now(T2),
  T1 < T2.

% For external actions that are relevant now only if the status is not compliant.
% TODO This is an output inference.
isRelevant(A,T1) :-
  externalAction(A,T1),
  isRelevantOnlyIfNonCompliant(A),
  -compliant(T1),
  now(T1).

% For external actions that are relevant in the future.
% TODO This is an output inference.
isRelevant(A,T1) :-
  externalAction(A,T1),
  not isRelevantOnlyIfNonCompliant(A),
  isRelevantInTheFuture(A),
  now(T2),
  T1 <= T2.

% For external actions that are relevant now.
% TODO This is an output inference.
isRelevant(A,T1) :-
  externalAction(A,T1),
  not isRelevantOnlyIfNonCompliant(A),
  now(T1).

% Messages.
% TODO This is an output inference.
message(A,T) :- h(message(A),T).

% #program base. % [MB]

% Convenience for making rules.
s_law(ifThen(B,H)) :- ifThen(B,H).
head(ifThen(B,H),H) :- ifThen(B,H).
body(ifThen(B,H),B) :- ifThen(B,H).

s_law(ifsThen((B1,B2),H)) :- ifsThen((B1,B2),H).
head(ifsThen((B1,B2),H),H) :- ifsThen((B1,B2),H).
body(ifsThen((B1,B2),H),B1) :- ifsThen((B1,B2),H).
body(ifsThen((B1,B2),H),B2) :- ifsThen((B1,B2),H).

s_law(ifsThen((B1,B2,B3),H)) :- ifsThen((B1,B2,B3),H).
head(ifsThen((B1,B2,B3),H),H) :- ifsThen((B1,B2,B3),H).
body(ifsThen((B1,B2,B3),H),B1) :- ifsThen((B1,B2,B3),H).
body(ifsThen((B1,B2,B3),H),B2) :- ifsThen((B1,B2,B3),H).
body(ifsThen((B1,B2,B3),H),B3) :- ifsThen((B1,B2,B3),H).

s_law(ifsThen((B1,B2,B3,B4),H)) :- ifsThen((B1,B2,B3,B4),H).
head(ifsThen((B1,B2,B3,B4),H),H) :- ifsThen((B1,B2,B3,B4),H).
body(ifsThen((B1,B2,B3,B4),H),B1) :- ifsThen((B1,B2,B3,B4),H).
body(ifsThen((B1,B2,B3,B4),H),B2) :- ifsThen((B1,B2,B3,B4),H).
body(ifsThen((B1,B2,B3,B4),H),B3) :- ifsThen((B1,B2,B3,B4),H).
body(ifsThen((B1,B2,B3,B4),H),B4) :- ifsThen((B1,B2,B3,B4),H).

s_law(ifsThen((B1,B2,B3,B4,B5),H)) :- ifsThen((B1,B2,B3,B4,B5),H).
head(ifsThen((B1,B2,B3,B4,B5),H),H) :- ifsThen((B1,B2,B3,B4,B5),H).
body(ifsThen((B1,B2,B3,B4,B5),H),B1) :- ifsThen((B1,B2,B3,B4,B5),H).
body(ifsThen((B1,B2,B3,B4,B5),H),B2) :- ifsThen((B1,B2,B3,B4,B5),H).
body(ifsThen((B1,B2,B3,B4,B5),H),B3) :- ifsThen((B1,B2,B3,B4,B5),H).
body(ifsThen((B1,B2,B3,B4,B5),H),B4) :- ifsThen((B1,B2,B3,B4,B5),H).
body(ifsThen((B1,B2,B3,B4,B5),H),B5) :- ifsThen((B1,B2,B3,B4,B5),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6),H)) :- ifsThen((B1,B2,B3,B4,B5,B6),H).
head(ifsThen((B1,B2,B3,B4,B5,B6),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6),H).
body(ifsThen((B1,B2,B3,B4,B5,B6),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6),H).
body(ifsThen((B1,B2,B3,B4,B5,B6),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6),H).
body(ifsThen((B1,B2,B3,B4,B5,B6),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6),H).
body(ifsThen((B1,B2,B3,B4,B5,B6),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6),H).
body(ifsThen((B1,B2,B3,B4,B5,B6),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6),H).
body(ifsThen((B1,B2,B3,B4,B5,B6),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H),B12) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B12) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H),B13) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B12) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B13) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H),B14) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B12) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B13) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B14) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H),B15) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B12) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B13) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B14) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B15) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H),B16) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B12) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B13) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B14) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B15) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B16) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H),B17) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B12) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B13) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B14) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B15) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B16) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B17) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H),B18) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B12) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B13) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B14) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B15) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B16) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B17) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B18) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H),B19) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19),H).

s_law(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H)) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
head(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),H) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B1) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B2) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B3) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B4) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B5) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B6) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B7) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B8) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B9) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B10) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B11) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B12) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B13) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B14) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B15) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B16) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B17) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B18) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B19) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).
body(ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H),B20) :- ifsThen((B1,B2,B3,B4,B5,B6,B7,B8,B9,B10,B11,B12,B13,B14,B15,B16,B17,B18,B19,B20),H).

% Convenience specification of defeasible state constraints
ifThen(B,H) :- normallyIfThen(B,H).
is_default(ifThen(B,H)) :- normallyIfThen(B,H).
ifsThen(B,H) :- normallyIfsThen(B,H).
is_default(ifsThen(B,H)) :- normallyIfsThen(B,H).

% Convenience specification of durative state constraints
ifThen(B,H) :- ifThenFor(B,H,D).
duration(ifThen(B,H),D) :- ifThenFor(B,H,D).
ifsThen(B,H) :- ifsThenFor(B,H,D).
duration(ifsThen(B,H),D) :- ifsThenFor(B,H,D).

% Convenience specification of no-extend state constraints
ifThenFor(B,H,D) :- ifThenForNoExtend(B,H,D).
is_no_extend(ifThen(B,H)) :- ifThenForNoExtend(B,H,D).
ifsThenFor(B,H,D) :- ifsThenForNoExtend(B,H,D).
is_no_extend(ifsThen(B,H)) :- ifsThenForNoExtend(B,H,D).

body_size(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(low))),4).
body_size(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(med))),4).
body_size(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(high))),4).
body_size(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_assumedInfectiousWithProb(high))),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))),3).
body_size(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),neg(coreExt_assumedInfectiousWithProb(low))),3).
body_size(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),neg(coreExt_assumedInfectiousWithProb(med))),3).
body_size(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),neg(coreExt_assumedInfectiousWithProb(high))),3).
body_size(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),3).
body_size(ifsThen((pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),3).
body_size(ifsThen((pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),3).
body_size(ifsThen((pos(initialized(feature(core_nothingOfConcern))),pos(core_nothingOfConcern),pos(core_nothingOfConcern)),pos(feature(core_nothingOfConcern))),2).
body_size(ifsThen((pos(initialized(feature(tempCheck_recentlyFevered))),pos(tempCheck_recentlyFevered),pos(core_assumedInfectiousWithDisease)),pos(feature(tempCheck_recentlyFevered))),3).
body_size(ifsThen((pos(initialized(feature(testing_recentlyTestedPositive))),pos(testing_recentlyTestedPositive),pos(core_assumedInfectiousWithDisease)),pos(feature(testing_recentlyTestedPositive))),3).
body_size(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_assumedInfectiousWithProb(low))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),3).
body_size(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_assumedInfectiousWithProb(med))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),3).
body_size(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_assumedInfectiousWithProb(high))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),3).
body_size(ifsThen((prev_pos(testing_posTestPos),neg(testing_posTestPos),neg(testing_posTestNeg)),pos(coreExt_userVariableBecameUnknown)),3).
body_size(ifsThen((pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_assumedInfectiousWithProb(high))),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(med))),2).
body_size(ifsThen((neg(testing_posTestPos),neg(testing_posTestNeg)),pos(testing_needsTestingReport)),2).
body_size(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbLowParam),pos(testing_needsNegTests(low))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))),2).
body_size(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbMedParam),pos(testing_needsNegTests(med))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))),2).
body_size(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbHighParam),pos(testing_needsNegTests(high))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))),2).
body_size(ifsThen((pos(coreExt_mayBeCleared),clearance_cpUserCanClearBadStatesParam),pos(cpreq(show(clearance_mayBeCleared)))),2).
body_size(ifsThen((neg(missing_some(testing_testingObs)),neg(testing_posTestPos)),pos(testing_posTestNeg)),2).
body_size(ifsThen((neg(symptomsSurvey_symptomsSurveyCompleted),neg(symptomsSurvey_symptomsWhileSickSurveyCompleted)),pos(missing_some(symptoms_symptomObs))),2).
body_size(ifsThen((neg(testingSurvey_testingSurveyCompleted),neg(testingSurvey_testingWhileSickSurveyCompleted)),pos(missing_some(testing_testingObs))),2).
body_size(ifsThen((expired(testing_posTestNeg),neg(testing_posTestPos)),pos(coreExt_userVariableBecameUnknown)),2).
body_size(ifThen(pos(core_assumedInfectiousWithDisease),pos(core_notReadyToReturn)),1).
body_size(ifThen(pos(core_atHighRiskIfInfectedWithDisease),pos(core_notReadyToReturn)),1).
body_size(ifThen(pos(core_missingInformation),pos(core_notReadyToReturn)),1).
body_size(ifThen(neg(core_notReadyToReturn),pos(core_readyToReturn)),1).
body_size(ifThen(neg(core_notReadyToReturn),pos(core_nothingOfConcern)),1).
body_size(ifThen(pos(coreExt_assumedInfectiousWithProb(high)),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(high))),1).
body_size(ifThen(pos(symptomsSurvey_fever),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_soreThroat),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_cough),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_lossOfSmell),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_difficultyBreathing),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_nausea),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_diarrhea),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_vomiting),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_headache),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_fatigue),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_muscleAches),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_fluSymptoms),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_unusualBruising),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsWhileSickSurvey_fever),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(neg(symptomsWhileSickSurvey_improvingSymptoms),pos(symptomsSurvey_surveyReportsSymptoms)),1).
body_size(ifThen(pos(symptomsSurvey_surveyReportsSymptoms),pos(cpreq(reset(symptomsSurvey_symptomsSurvey)))),1).
body_size(ifThen(pos(tempCheck_fever),pos(symptoms_symptomaticPos)),1).
body_size(ifThen(pos(tempCheck_checkpointVisited),neg(uireq(show(tempCheck_visitCheckpoint)))),1).
body_size(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(tempCheck_visitCheckpoint)))),1).
body_size(ifThen(pos(uireq(show(symptomsSurvey_symptomsSurvey))),neg(uireq(show(tempCheck_visitCheckpoint)))),1).
body_size(ifThen(neg(tempCheck_checkpointVisited),pos(missing_some(symptoms_symptomObs))),1).
body_size(ifThen(pos(exposureSurvey_closeContact_covid),pos(exposureSurvey_surveyReportsExposure)),1).
body_size(ifThen(pos(exposureSurvey_intlTravel),pos(exposureSurvey_surveyReportsExposure)),1).
body_size(ifThen(pos(exposureSurvey_closeContact_intlTravel),pos(exposureSurvey_surveyReportsExposure)),1).
body_size(ifThen(pos(exposureSurvey_highRiskTravel),pos(exposureSurvey_surveyReportsExposure)),1).
body_size(ifThen(pos(exposureSurvey_surveyReportsExposure),pos(cpreq(reset(exposureSurvey_exposureSurvey)))),1).
body_size(ifThen(pos(testing_posTestPos),pos(coreExt_assumedInfectiousWithProb(high))),1).
body_size(ifThen(pos(testing_posTestPos),pos(coreExt_mayBeCleared)),1).
body_size(ifThen(pos(coreExt_cleared),neg(testing_posTestPos)),1).
body_size(ifThen(pos(coreExt_cleared),pos(testing_posTestNeg)),1).
body_size(ifThen(pos(testingSurvey_posPcrTest),pos(testingSurvey_surveyReportsPosTest)),1).
body_size(ifThen(pos(testingSurvey_surveyReportsPosTest),pos(testing_posTestPos)),1).
body_size(ifThen(pos(testingSurvey_surveyReportsPosTest),pos(cpreq(reset(testingSurvey_testingSurvey)))),1).
body_size(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(cpreq(reset(testingSurvey_testingSurvey)))),1).
body_size(ifThen(pos(cpreq(show(clearance_mayBeCleared))),pos(cpreq(show(clearance_mayBeDeniedClearance)))),1).
body_size(ifThen(pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbLowParam),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),1).
body_size(ifThen(pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbMedParam),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),1).
body_size(ifThen(pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbHighParam),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),1).
body_size(ifThen(pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance),pos(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious)))),1).
body_size(ifThen(pos(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious))),pos(cpreq(show(clearance_mayBeDeniedClearanceAfterAssumedInfectious)))),1).
body_size(ifThen(pos(clearance_clearanceReceivedAfterAssumedInfectious),pos(coreExt_receivedClearanceAfterAssumedInfectious)),1).
body_size(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(testing_needsNegTests(low))),1).
body_size(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(testing_needsNegTests(med))),1).
body_size(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(testing_needsNegTests(high))),1).
body_size(ifThen(pos(testingWhileSickSurvey_receivedNegativeTests),neg(testing_needsNegTests(low))),1).
body_size(ifThen(pos(testingWhileSickSurvey_receivedNegativeTests),neg(testing_needsNegTests(med))),1).
body_size(ifThen(pos(testingWhileSickSurvey_receivedNegativeTests),neg(testing_needsNegTests(high))),1).
body_size(ifThen(pos(symptomsSurvey_surveyReportsSymptoms),pos(symptoms_symptomaticPos)),1).
body_size(ifThen(pos(symptomsSurvey_fever),pos(symptoms_feverishPos)),1).
body_size(ifThen(pos(symptomsWhileSickSurvey_fever),pos(symptoms_feverishPos)),1).
body_size(ifThen(pos(tempCheck_fever),pos(symptoms_feverishPos)),1).
body_size(ifThen(pos(tempCheck_fever),pos(tempCheck_recentlyFevered)),1).
body_size(ifThen(pos(exposureSurvey_surveyReportsExposure),pos(exposure_exposedPos)),1).
body_size(ifThen(pos(clearance_clearanceReceived),pos(coreExt_cleared)),1).
body_size(ifThen(pos(testing_posTestPos),pos(testing_recentlyTestedPositive)),1).
body_size(ifThen(pos(coreExt_userVariableBecameUnknown),neg(tempCheck_checkpointVisited)),1).
body_size(ifThen(pos(coreExt_userVariableBecameUnknown),neg(symptomsSurvey_symptomsSurveyCompleted)),1).
body_size(ifThen(pos(coreExt_userVariableBecameUnknown),neg(exposureSurvey_exposureSurveyCompleted)),1).
body_size(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testingSurvey_testingSurveyCompleted)),1).
body_size(ifThen(pos(coreExt_userVariableBecameUnknown),neg(symptomsSurvey_symptomsWhileSickSurveyCompleted)),1).
body_size(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testingSurvey_testingWhileSickSurveyCompleted)),1).
body_size(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testing_posTestPos)),1).
body_size(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testing_posTestNeg)),1).
body_size(ifThen(pos(coreExt_assumedInfectiousWithProb(low)),pos(core_assumedInfectiousWithDisease)),1).
body_size(ifThen(pos(coreExt_assumedInfectiousWithProb(med)),pos(core_assumedInfectiousWithDisease)),1).
body_size(ifThen(pos(coreExt_assumedInfectiousWithProb(high)),pos(core_assumedInfectiousWithDisease)),1).
body_size(ifThen(pos(coreExt_cleared),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))),1).
body_size(ifThen(pos(coreExt_cleared),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))),1).
body_size(ifThen(pos(coreExt_cleared),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))),1).
body_size(ifThen(pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low)),pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))))),1).
body_size(ifThen(pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(med)),pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(med))))),1).
body_size(ifThen(pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(high)),pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(high))))),1).
body_size(ifThen(pos(symptomsSurvey_symptomsSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsSurvey)))),1).
body_size(ifThen(pos(exposureSurvey_exposureSurveyCompleted),neg(uireq(show(exposureSurvey_exposureSurvey)))),1).
body_size(ifThen(pos(testingSurvey_testingSurveyCompleted),neg(uireq(show(testingSurvey_testingSurvey)))),1).
body_size(ifThen(pos(symptomsSurvey_symptomsWhileSickSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsSurvey)))),1).
body_size(ifThen(pos(testingSurvey_testingWhileSickSurveyCompleted),neg(uireq(show(testingSurvey_testingSurvey)))),1).
body_size(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(symptomsSurvey_symptomsSurvey)))),1).
body_size(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(exposureSurvey_exposureSurvey)))),1).
body_size(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(testingSurvey_testingSurvey)))),1).
body_size(ifThen(pos(symptomsSurvey_symptomsSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsWhileSickSurvey)))),1).
body_size(ifThen(pos(exposureSurvey_exposureSurveyCompleted),neg(uireq(show(na)))),1).
body_size(ifThen(pos(testingSurvey_testingSurveyCompleted),neg(uireq(show(testingSurvey_testingWhileSickSurvey)))),1).
body_size(ifThen(pos(symptomsSurvey_symptomsWhileSickSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsWhileSickSurvey)))),1).
body_size(ifThen(pos(testingSurvey_testingWhileSickSurveyCompleted),neg(uireq(show(testingSurvey_testingWhileSickSurvey)))),1).
body_size(ifThen(neg(core_assumedInfectiousWithDisease),neg(uireq(show(symptomsSurvey_symptomsWhileSickSurvey)))),1).
body_size(ifThen(neg(core_assumedInfectiousWithDisease),neg(uireq(show(testingSurvey_testingWhileSickSurvey)))),1).
body_size(ifThen(neg(exposureSurvey_exposureSurveyCompleted),pos(missing_some(exposure_exposureObs))),1).
body_size(ifThen(pos(core_nothingOfConcern),pos(initialized(feature(core_nothingOfConcern)))),1).
body_size(ifThen(pos(tempCheck_fever),pos(initialized(feature(tempCheck_recentlyFevered)))),1).
body_size(ifThen(pos(testing_posTestPos),pos(initialized(feature(testing_recentlyTestedPositive)))),1).
body_size(ifThen(pos(coreExt_assumedInfectiousWithProb(low)),pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))))),1).
body_size(ifThen(pos(coreExt_assumedInfectiousWithProb(med)),pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))))),1).
body_size(ifThen(pos(coreExt_assumedInfectiousWithProb(high)),pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))))),1).
body_size(ifThen(pos(testing_posTestNeg),pos(initialized(feature(testing_recentlyTestedPositive)))),1).
body_size(ifThen(pos(testing_posTestPos),neg(testing_posTestNeg)),1).
body_size(ifThen(pos(testing_posTestNeg),neg(testing_posTestPos)),1).
body_size(ifThen(pos(coreExt_cleared),pos(core_nothingOfConcern)),1).
body_size(ifThen(pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance),pos(core_assumedInfectiousWithDisease)),1).
body_size(ifThen(pos(testing_needsTestingReport),pos(core_missingInformation)),1).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(low))),5,nil).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(med))),5,nil).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(high))),5,nil).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_assumedInfectiousWithProb(high))),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))),4,nil).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),neg(coreExt_assumedInfectiousWithProb(low))),4,nil).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),neg(coreExt_assumedInfectiousWithProb(med))),4,nil).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),neg(coreExt_assumedInfectiousWithProb(high))),4,nil).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),4,nil).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),4,nil).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),4,nil).
newbody(ifsThen((pos(initialized(feature(core_nothingOfConcern))),pos(core_nothingOfConcern),pos(core_nothingOfConcern)),pos(feature(core_nothingOfConcern))),3,nil).
newbody(ifsThen((pos(initialized(feature(tempCheck_recentlyFevered))),pos(tempCheck_recentlyFevered),pos(core_assumedInfectiousWithDisease)),pos(feature(tempCheck_recentlyFevered))),4,nil).
newbody(ifsThen((pos(initialized(feature(testing_recentlyTestedPositive))),pos(testing_recentlyTestedPositive),pos(core_assumedInfectiousWithDisease)),pos(feature(testing_recentlyTestedPositive))),4,nil).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_assumedInfectiousWithProb(low))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),4,nil).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_assumedInfectiousWithProb(med))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),4,nil).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_assumedInfectiousWithProb(high))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),4,nil).
newbody(ifsThen((prev_pos(testing_posTestPos),neg(testing_posTestPos),neg(testing_posTestNeg)),pos(coreExt_userVariableBecameUnknown)),4,nil).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_assumedInfectiousWithProb(high))),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(med))),3,nil).
newbody(ifsThen((neg(testing_posTestPos),neg(testing_posTestNeg)),pos(testing_needsTestingReport)),3,nil).
newbody(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbLowParam),pos(testing_needsNegTests(low))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))),3,nil).
newbody(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbMedParam),pos(testing_needsNegTests(med))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))),3,nil).
newbody(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbHighParam),pos(testing_needsNegTests(high))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))),3,nil).
newbody(ifsThen((pos(coreExt_mayBeCleared),clearance_cpUserCanClearBadStatesParam),pos(cpreq(show(clearance_mayBeCleared)))),3,nil).
newbody(ifsThen((neg(missing_some(testing_testingObs)),neg(testing_posTestPos)),pos(testing_posTestNeg)),3,nil).
newbody(ifsThen((neg(symptomsSurvey_symptomsSurveyCompleted),neg(symptomsSurvey_symptomsWhileSickSurveyCompleted)),pos(missing_some(symptoms_symptomObs))),3,nil).
newbody(ifsThen((neg(testingSurvey_testingSurveyCompleted),neg(testingSurvey_testingWhileSickSurveyCompleted)),pos(missing_some(testing_testingObs))),3,nil).
newbody(ifsThen((expired(testing_posTestNeg),neg(testing_posTestPos)),pos(coreExt_userVariableBecameUnknown)),3,nil).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),pos(core_notReadyToReturn)),2,nil).
newbody(ifThen(pos(core_atHighRiskIfInfectedWithDisease),pos(core_notReadyToReturn)),2,nil).
newbody(ifThen(pos(core_missingInformation),pos(core_notReadyToReturn)),2,nil).
newbody(ifThen(neg(core_notReadyToReturn),pos(core_readyToReturn)),2,nil).
newbody(ifThen(neg(core_notReadyToReturn),pos(core_nothingOfConcern)),2,nil).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(high)),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(high))),2,nil).
newbody(ifThen(pos(symptomsSurvey_fever),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_soreThroat),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_cough),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_lossOfSmell),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_difficultyBreathing),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_nausea),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_diarrhea),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_vomiting),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_headache),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_fatigue),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_muscleAches),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_fluSymptoms),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_unusualBruising),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsWhileSickSurvey_fever),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(neg(symptomsWhileSickSurvey_improvingSymptoms),pos(symptomsSurvey_surveyReportsSymptoms)),2,nil).
newbody(ifThen(pos(symptomsSurvey_surveyReportsSymptoms),pos(cpreq(reset(symptomsSurvey_symptomsSurvey)))),2,nil).
newbody(ifThen(pos(tempCheck_fever),pos(symptoms_symptomaticPos)),2,nil).
newbody(ifThen(pos(tempCheck_checkpointVisited),neg(uireq(show(tempCheck_visitCheckpoint)))),2,nil).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(tempCheck_visitCheckpoint)))),2,nil).
newbody(ifThen(pos(uireq(show(symptomsSurvey_symptomsSurvey))),neg(uireq(show(tempCheck_visitCheckpoint)))),2,nil).
newbody(ifThen(neg(tempCheck_checkpointVisited),pos(missing_some(symptoms_symptomObs))),2,nil).
newbody(ifThen(pos(exposureSurvey_closeContact_covid),pos(exposureSurvey_surveyReportsExposure)),2,nil).
newbody(ifThen(pos(exposureSurvey_intlTravel),pos(exposureSurvey_surveyReportsExposure)),2,nil).
newbody(ifThen(pos(exposureSurvey_closeContact_intlTravel),pos(exposureSurvey_surveyReportsExposure)),2,nil).
newbody(ifThen(pos(exposureSurvey_highRiskTravel),pos(exposureSurvey_surveyReportsExposure)),2,nil).
newbody(ifThen(pos(exposureSurvey_surveyReportsExposure),pos(cpreq(reset(exposureSurvey_exposureSurvey)))),2,nil).
newbody(ifThen(pos(testing_posTestPos),pos(coreExt_assumedInfectiousWithProb(high))),2,nil).
newbody(ifThen(pos(testing_posTestPos),pos(coreExt_mayBeCleared)),2,nil).
newbody(ifThen(pos(coreExt_cleared),neg(testing_posTestPos)),2,nil).
newbody(ifThen(pos(coreExt_cleared),pos(testing_posTestNeg)),2,nil).
newbody(ifThen(pos(testingSurvey_posPcrTest),pos(testingSurvey_surveyReportsPosTest)),2,nil).
newbody(ifThen(pos(testingSurvey_surveyReportsPosTest),pos(testing_posTestPos)),2,nil).
newbody(ifThen(pos(testingSurvey_surveyReportsPosTest),pos(cpreq(reset(testingSurvey_testingSurvey)))),2,nil).
newbody(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(cpreq(reset(testingSurvey_testingSurvey)))),2,nil).
newbody(ifThen(pos(cpreq(show(clearance_mayBeCleared))),pos(cpreq(show(clearance_mayBeDeniedClearance)))),2,nil).
newbody(ifThen(pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbLowParam),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),2,nil).
newbody(ifThen(pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbMedParam),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),2,nil).
newbody(ifThen(pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbHighParam),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),2,nil).
newbody(ifThen(pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance),pos(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious)))),2,nil).
newbody(ifThen(pos(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious))),pos(cpreq(show(clearance_mayBeDeniedClearanceAfterAssumedInfectious)))),2,nil).
newbody(ifThen(pos(clearance_clearanceReceivedAfterAssumedInfectious),pos(coreExt_receivedClearanceAfterAssumedInfectious)),2,nil).
newbody(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(testing_needsNegTests(low))),2,nil).
newbody(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(testing_needsNegTests(med))),2,nil).
newbody(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(testing_needsNegTests(high))),2,nil).
newbody(ifThen(pos(testingWhileSickSurvey_receivedNegativeTests),neg(testing_needsNegTests(low))),2,nil).
newbody(ifThen(pos(testingWhileSickSurvey_receivedNegativeTests),neg(testing_needsNegTests(med))),2,nil).
newbody(ifThen(pos(testingWhileSickSurvey_receivedNegativeTests),neg(testing_needsNegTests(high))),2,nil).
newbody(ifThen(pos(symptomsSurvey_surveyReportsSymptoms),pos(symptoms_symptomaticPos)),2,nil).
newbody(ifThen(pos(symptomsSurvey_fever),pos(symptoms_feverishPos)),2,nil).
newbody(ifThen(pos(symptomsWhileSickSurvey_fever),pos(symptoms_feverishPos)),2,nil).
newbody(ifThen(pos(tempCheck_fever),pos(symptoms_feverishPos)),2,nil).
newbody(ifThen(pos(tempCheck_fever),pos(tempCheck_recentlyFevered)),2,nil).
newbody(ifThen(pos(exposureSurvey_surveyReportsExposure),pos(exposure_exposedPos)),2,nil).
newbody(ifThen(pos(clearance_clearanceReceived),pos(coreExt_cleared)),2,nil).
newbody(ifThen(pos(testing_posTestPos),pos(testing_recentlyTestedPositive)),2,nil).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(tempCheck_checkpointVisited)),2,nil).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(symptomsSurvey_symptomsSurveyCompleted)),2,nil).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(exposureSurvey_exposureSurveyCompleted)),2,nil).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testingSurvey_testingSurveyCompleted)),2,nil).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(symptomsSurvey_symptomsWhileSickSurveyCompleted)),2,nil).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testingSurvey_testingWhileSickSurveyCompleted)),2,nil).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testing_posTestPos)),2,nil).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testing_posTestNeg)),2,nil).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(low)),pos(core_assumedInfectiousWithDisease)),2,nil).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(med)),pos(core_assumedInfectiousWithDisease)),2,nil).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(high)),pos(core_assumedInfectiousWithDisease)),2,nil).
newbody(ifThen(pos(coreExt_cleared),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))),2,nil).
newbody(ifThen(pos(coreExt_cleared),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))),2,nil).
newbody(ifThen(pos(coreExt_cleared),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))),2,nil).
newbody(ifThen(pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low)),pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))))),2,nil).
newbody(ifThen(pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(med)),pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(med))))),2,nil).
newbody(ifThen(pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(high)),pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(high))))),2,nil).
newbody(ifThen(pos(symptomsSurvey_symptomsSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsSurvey)))),2,nil).
newbody(ifThen(pos(exposureSurvey_exposureSurveyCompleted),neg(uireq(show(exposureSurvey_exposureSurvey)))),2,nil).
newbody(ifThen(pos(testingSurvey_testingSurveyCompleted),neg(uireq(show(testingSurvey_testingSurvey)))),2,nil).
newbody(ifThen(pos(symptomsSurvey_symptomsWhileSickSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsSurvey)))),2,nil).
newbody(ifThen(pos(testingSurvey_testingWhileSickSurveyCompleted),neg(uireq(show(testingSurvey_testingSurvey)))),2,nil).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(symptomsSurvey_symptomsSurvey)))),2,nil).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(exposureSurvey_exposureSurvey)))),2,nil).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(testingSurvey_testingSurvey)))),2,nil).
newbody(ifThen(pos(symptomsSurvey_symptomsSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsWhileSickSurvey)))),2,nil).
newbody(ifThen(pos(exposureSurvey_exposureSurveyCompleted),neg(uireq(show(na)))),2,nil).
newbody(ifThen(pos(testingSurvey_testingSurveyCompleted),neg(uireq(show(testingSurvey_testingWhileSickSurvey)))),2,nil).
newbody(ifThen(pos(symptomsSurvey_symptomsWhileSickSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsWhileSickSurvey)))),2,nil).
newbody(ifThen(pos(testingSurvey_testingWhileSickSurveyCompleted),neg(uireq(show(testingSurvey_testingWhileSickSurvey)))),2,nil).
newbody(ifThen(neg(core_assumedInfectiousWithDisease),neg(uireq(show(symptomsSurvey_symptomsWhileSickSurvey)))),2,nil).
newbody(ifThen(neg(core_assumedInfectiousWithDisease),neg(uireq(show(testingSurvey_testingWhileSickSurvey)))),2,nil).
newbody(ifThen(neg(exposureSurvey_exposureSurveyCompleted),pos(missing_some(exposure_exposureObs))),2,nil).
newbody(ifThen(pos(core_nothingOfConcern),pos(initialized(feature(core_nothingOfConcern)))),2,nil).
newbody(ifThen(pos(tempCheck_fever),pos(initialized(feature(tempCheck_recentlyFevered)))),2,nil).
newbody(ifThen(pos(testing_posTestPos),pos(initialized(feature(testing_recentlyTestedPositive)))),2,nil).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(low)),pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))))),2,nil).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(med)),pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))))),2,nil).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(high)),pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))))),2,nil).
newbody(ifThen(pos(testing_posTestNeg),pos(initialized(feature(testing_recentlyTestedPositive)))),2,nil).
newbody(ifThen(pos(testing_posTestPos),neg(testing_posTestNeg)),2,nil).
newbody(ifThen(pos(testing_posTestNeg),neg(testing_posTestPos)),2,nil).
newbody(ifThen(pos(coreExt_cleared),pos(core_nothingOfConcern)),2,nil).
newbody(ifThen(pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance),pos(core_assumedInfectiousWithDisease)),2,nil).
newbody(ifThen(pos(testing_needsTestingReport),pos(core_missingInformation)),2,nil).
next(1,121).
next(0,1).
newbody(ifsThen((neg(testingSurvey_testingSurveyCompleted),neg(testingSurvey_testingWhileSickSurveyCompleted)),pos(missing_some(testing_testingObs))),2,neg(testingSurvey_testingWhileSickSurveyCompleted)).
newbody(ifsThen((neg(symptomsSurvey_symptomsSurveyCompleted),neg(symptomsSurvey_symptomsWhileSickSurveyCompleted)),pos(missing_some(symptoms_symptomObs))),1,neg(symptomsSurvey_symptomsWhileSickSurveyCompleted)).
newbody(ifsThen((neg(testingSurvey_testingSurveyCompleted),neg(testingSurvey_testingWhileSickSurveyCompleted)),pos(missing_some(testing_testingObs))),1,neg(testingSurvey_testingSurveyCompleted)).
newbody(ifThen(neg(exposureSurvey_exposureSurveyCompleted),pos(missing_some(exposure_exposureObs))),1,neg(exposureSurvey_exposureSurveyCompleted)).
newbody(ifsThen((neg(symptomsSurvey_symptomsSurveyCompleted),neg(symptomsSurvey_symptomsWhileSickSurveyCompleted)),pos(missing_some(symptoms_symptomObs))),2,neg(symptomsSurvey_symptomsSurveyCompleted)).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_assumedInfectiousWithProb(high))),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))),1,neg(coreExt_assumedInfectiousWithProb(high))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_assumedInfectiousWithProb(high))),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(med))),1,neg(coreExt_assumedInfectiousWithProb(high))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_assumedInfectiousWithProb(high))),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))),2,neg(coreExt_assumedInfectiousWithProb(med))).
newbody(ifThen(neg(tempCheck_checkpointVisited),pos(missing_some(symptoms_symptomObs))),1,neg(tempCheck_checkpointVisited)).
newbody(ifsThen((prev_pos(testing_posTestPos),neg(testing_posTestPos),neg(testing_posTestNeg)),pos(coreExt_userVariableBecameUnknown)),2,neg(testing_posTestNeg)).
newbody(ifsThen((neg(testing_posTestPos),neg(testing_posTestNeg)),pos(testing_needsTestingReport)),2,neg(testing_posTestNeg)).
newbody(ifsThen((prev_pos(testing_posTestPos),neg(testing_posTestPos),neg(testing_posTestNeg)),pos(coreExt_userVariableBecameUnknown)),3,neg(testing_posTestPos)).
newbody(ifsThen((neg(testing_posTestPos),neg(testing_posTestNeg)),pos(testing_needsTestingReport)),1,neg(testing_posTestPos)).
newbody(ifsThen((neg(missing_some(testing_testingObs)),neg(testing_posTestPos)),pos(testing_posTestNeg)),2,neg(testing_posTestPos)).
newbody(ifsThen((expired(testing_posTestNeg),neg(testing_posTestPos)),pos(coreExt_userVariableBecameUnknown)),2,neg(testing_posTestPos)).
newbody(ifsThen((neg(missing_some(testing_testingObs)),neg(testing_posTestPos)),pos(testing_posTestNeg)),1,neg(missing_some(testing_testingObs))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),neg(coreExt_assumedInfectiousWithProb(high))),1,neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),neg(coreExt_assumedInfectiousWithProb(med))),3,neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),neg(coreExt_assumedInfectiousWithProb(low))),1,neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(high))),4,neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),neg(coreExt_assumedInfectiousWithProb(high))),3,neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),1,neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(med))),2,neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),neg(coreExt_assumedInfectiousWithProb(med))),2,neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),2,neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(low))),1,neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),neg(coreExt_assumedInfectiousWithProb(low))),3,neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),2,neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))).
newbody(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(cpreq(reset(testingSurvey_testingSurvey)))),1,neg(testingWhileSickSurvey_receivedNegativeTests)).
newbody(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(testing_needsNegTests(low))),1,neg(testingWhileSickSurvey_receivedNegativeTests)).
newbody(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(testing_needsNegTests(med))),1,neg(testingWhileSickSurvey_receivedNegativeTests)).
newbody(ifThen(neg(testingWhileSickSurvey_receivedNegativeTests),pos(testing_needsNegTests(high))),1,neg(testingWhileSickSurvey_receivedNegativeTests)).
newbody(ifThen(neg(core_assumedInfectiousWithDisease),neg(uireq(show(symptomsSurvey_symptomsWhileSickSurvey)))),1,neg(core_assumedInfectiousWithDisease)).
newbody(ifThen(neg(core_assumedInfectiousWithDisease),neg(uireq(show(testingSurvey_testingWhileSickSurvey)))),1,neg(core_assumedInfectiousWithDisease)).
newbody(ifThen(neg(core_notReadyToReturn),pos(core_readyToReturn)),1,neg(core_notReadyToReturn)).
newbody(ifThen(neg(core_notReadyToReturn),pos(core_nothingOfConcern)),1,neg(core_notReadyToReturn)).
newbody(ifThen(pos(uireq(show(symptomsSurvey_symptomsSurvey))),neg(uireq(show(tempCheck_visitCheckpoint)))),1,pos(uireq(show(symptomsSurvey_symptomsSurvey)))).
newbody(ifThen(pos(testingSurvey_testingSurveyCompleted),neg(uireq(show(testingSurvey_testingSurvey)))),1,pos(testingSurvey_testingSurveyCompleted)).
newbody(ifThen(pos(testingSurvey_testingSurveyCompleted),neg(uireq(show(testingSurvey_testingWhileSickSurvey)))),1,pos(testingSurvey_testingSurveyCompleted)).
newbody(ifThen(pos(testingSurvey_posPcrTest),pos(testingSurvey_surveyReportsPosTest)),1,pos(testingSurvey_posPcrTest)).
newbody(ifThen(pos(tempCheck_checkpointVisited),neg(uireq(show(tempCheck_visitCheckpoint)))),1,pos(tempCheck_checkpointVisited)).
newbody(ifThen(pos(symptomsSurvey_symptomsSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsSurvey)))),1,pos(symptomsSurvey_symptomsSurveyCompleted)).
newbody(ifThen(pos(symptomsSurvey_symptomsSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsWhileSickSurvey)))),1,pos(symptomsSurvey_symptomsSurveyCompleted)).
newbody(ifThen(pos(exposureSurvey_exposureSurveyCompleted),neg(uireq(show(exposureSurvey_exposureSurvey)))),1,pos(exposureSurvey_exposureSurveyCompleted)).
newbody(ifThen(pos(exposureSurvey_exposureSurveyCompleted),neg(uireq(show(na)))),1,pos(exposureSurvey_exposureSurveyCompleted)).
newbody(ifThen(pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbHighParam),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),1,pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbHighParam)).
newbody(ifThen(pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbMedParam),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),1,pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbMedParam)).
newbody(ifThen(pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbLowParam),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),1,pos(clearance_guidanceRequiresClearanceForAssumedInfectiousWithProbLowParam)).
newbody(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbMedParam),pos(testing_needsNegTests(med))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))),1,pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbMedParam)).
newbody(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbLowParam),pos(testing_needsNegTests(low))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))),2,pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbLowParam)).
newbody(ifThen(pos(clearance_clearanceReceivedAfterAssumedInfectious),pos(coreExt_receivedClearanceAfterAssumedInfectious)),1,pos(clearance_clearanceReceivedAfterAssumedInfectious)).
newbody(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbLowParam),pos(testing_needsNegTests(low))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))),1,pos(testing_needsNegTests(low))).
newbody(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbMedParam),pos(testing_needsNegTests(med))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))),2,pos(testing_needsNegTests(med))).
newbody(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbHighParam),pos(testing_needsNegTests(high))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))),2,pos(testing_needsNegTests(high))).
newbody(ifsThen((pos(initialized(feature(core_nothingOfConcern))),pos(core_nothingOfConcern),pos(core_nothingOfConcern)),pos(feature(core_nothingOfConcern))),1,pos(core_nothingOfConcern)).
newbody(ifThen(pos(core_nothingOfConcern),pos(initialized(feature(core_nothingOfConcern)))),1,pos(core_nothingOfConcern)).
newbody(ifThen(pos(testingSurvey_surveyReportsPosTest),pos(testing_posTestPos)),1,pos(testingSurvey_surveyReportsPosTest)).
newbody(ifThen(pos(testingSurvey_surveyReportsPosTest),pos(cpreq(reset(testingSurvey_testingSurvey)))),1,pos(testingSurvey_surveyReportsPosTest)).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(high))),1,pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),2,pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(med))),3,pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),3,pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(low))),3,pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),3,pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(low))),4,pos(coreExt_receivedClearanceAfterAssumedInfectious)).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(med))),4,pos(coreExt_receivedClearanceAfterAssumedInfectious)).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(high))),2,pos(coreExt_receivedClearanceAfterAssumedInfectious)).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_assumedInfectiousWithProb(low))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),3,pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_assumedInfectiousWithProb(med))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),2,pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(tempCheck_checkpointVisited)),1,pos(coreExt_userVariableBecameUnknown)).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(symptomsSurvey_symptomsSurveyCompleted)),1,pos(coreExt_userVariableBecameUnknown)).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(exposureSurvey_exposureSurveyCompleted)),1,pos(coreExt_userVariableBecameUnknown)).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testingSurvey_testingSurveyCompleted)),1,pos(coreExt_userVariableBecameUnknown)).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(symptomsSurvey_symptomsWhileSickSurveyCompleted)),1,pos(coreExt_userVariableBecameUnknown)).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testingSurvey_testingWhileSickSurveyCompleted)),1,pos(coreExt_userVariableBecameUnknown)).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testing_posTestPos)),1,pos(coreExt_userVariableBecameUnknown)).
newbody(ifThen(pos(coreExt_userVariableBecameUnknown),neg(testing_posTestNeg)),1,pos(coreExt_userVariableBecameUnknown)).
newbody(ifThen(pos(testing_posTestNeg),pos(initialized(feature(testing_recentlyTestedPositive)))),1,pos(testing_posTestNeg)).
newbody(ifThen(pos(testing_posTestNeg),neg(testing_posTestPos)),1,pos(testing_posTestNeg)).
newbody(ifThen(pos(testing_needsTestingReport),pos(core_missingInformation)),1,pos(testing_needsTestingReport)).
newbody(ifThen(pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(med)),pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(med))))),1,pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(med))).
newbody(ifThen(pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low)),pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))))),1,pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))).
newbody(ifThen(pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance),pos(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious)))),1,pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)).
newbody(ifThen(pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance),pos(core_assumedInfectiousWithDisease)),1,pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)).
newbody(ifsThen((expired(testing_posTestNeg),neg(testing_posTestPos)),pos(coreExt_userVariableBecameUnknown)),1,expired(testing_posTestNeg)).
newbody(ifsThen((prev_pos(testing_posTestPos),neg(testing_posTestPos),neg(testing_posTestNeg)),pos(coreExt_userVariableBecameUnknown)),1,prev_pos(testing_posTestPos)).
newbody(ifsThen((pos(initialized(feature(core_nothingOfConcern))),pos(core_nothingOfConcern),pos(core_nothingOfConcern)),pos(feature(core_nothingOfConcern))),2,pos(initialized(feature(core_nothingOfConcern)))).
newbody(ifThen(pos(testing_posTestPos),pos(coreExt_assumedInfectiousWithProb(high))),1,pos(testing_posTestPos)).
newbody(ifThen(pos(testing_posTestPos),pos(coreExt_mayBeCleared)),1,pos(testing_posTestPos)).
newbody(ifThen(pos(testing_posTestPos),pos(testing_recentlyTestedPositive)),1,pos(testing_posTestPos)).
newbody(ifThen(pos(testing_posTestPos),pos(initialized(feature(testing_recentlyTestedPositive)))),1,pos(testing_posTestPos)).
newbody(ifThen(pos(testing_posTestPos),neg(testing_posTestNeg)),1,pos(testing_posTestPos)).
newbody(ifsThen((pos(initialized(feature(testing_recentlyTestedPositive))),pos(testing_recentlyTestedPositive),pos(core_assumedInfectiousWithDisease)),pos(feature(testing_recentlyTestedPositive))),2,pos(initialized(feature(testing_recentlyTestedPositive)))).
newbody(ifThen(pos(core_missingInformation),pos(core_notReadyToReturn)),1,pos(core_missingInformation)).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_assumedInfectiousWithProb(high))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),3,pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))).
newbody(ifsThen((pos(initialized(feature(tempCheck_recentlyFevered))),pos(tempCheck_recentlyFevered),pos(core_assumedInfectiousWithDisease)),pos(feature(tempCheck_recentlyFevered))),1,pos(core_assumedInfectiousWithDisease)).
newbody(ifsThen((pos(initialized(feature(testing_recentlyTestedPositive))),pos(testing_recentlyTestedPositive),pos(core_assumedInfectiousWithDisease)),pos(feature(testing_recentlyTestedPositive))),3,pos(core_assumedInfectiousWithDisease)).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),pos(core_notReadyToReturn)),1,pos(core_assumedInfectiousWithDisease)).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(tempCheck_visitCheckpoint)))),1,pos(core_assumedInfectiousWithDisease)).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(symptomsSurvey_symptomsSurvey)))),1,pos(core_assumedInfectiousWithDisease)).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(exposureSurvey_exposureSurvey)))),1,pos(core_assumedInfectiousWithDisease)).
newbody(ifThen(pos(core_assumedInfectiousWithDisease),neg(uireq(show(testingSurvey_testingSurvey)))),1,pos(core_assumedInfectiousWithDisease)).
newbody(ifThen(pos(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious))),pos(cpreq(show(clearance_mayBeDeniedClearanceAfterAssumedInfectious)))),1,pos(cpreq(show(clearance_mayBeClearedAfterAssumedInfectious)))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(high))),3,prev_pos(coreExt_assumedInfectiousWithProb(high))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),neg(coreExt_assumedInfectiousWithProb(high))),2,prev_pos(coreExt_assumedInfectiousWithProb(high))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(high)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(high))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),3,pos(coreExt_assumedInfectiousWithProb(high))).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_assumedInfectiousWithProb(high))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),2,pos(coreExt_assumedInfectiousWithProb(high))).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(high)),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(high))),1,pos(coreExt_assumedInfectiousWithProb(high))).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(high)),pos(core_assumedInfectiousWithDisease)),1,pos(coreExt_assumedInfectiousWithProb(high))).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(high)),pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))))),1,pos(coreExt_assumedInfectiousWithProb(high))).
newbody(ifsThen((pos(coreExt_mayBeCleared),clearance_cpUserCanClearBadStatesParam),pos(cpreq(show(clearance_mayBeCleared)))),2,pos(coreExt_mayBeCleared)).
newbody(ifsThen((pos(initialized(feature(testing_recentlyTestedPositive))),pos(testing_recentlyTestedPositive),pos(core_assumedInfectiousWithDisease)),pos(feature(testing_recentlyTestedPositive))),1,pos(testing_recentlyTestedPositive)).
newbody(ifThen(pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(high)),pos(uireq(show(coreExt_needsGuidanceForAssumedInfectiousWithProb(high))))),1,pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(high))).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)),pos(coreExt_assumedInfectiousWithProb(high))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high)))),1,pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))))).
newbody(ifThen(pos(cpreq(show(clearance_mayBeCleared))),pos(cpreq(show(clearance_mayBeDeniedClearance)))),1,pos(cpreq(show(clearance_mayBeCleared)))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(low))),2,prev_pos(coreExt_assumedInfectiousWithProb(low))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med)),pos(coreExt_receivedClearanceAfterAssumedInfectious)),neg(coreExt_assumedInfectiousWithProb(med))),1,prev_pos(coreExt_assumedInfectiousWithProb(med))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_assumedInfectiousWithProb(high))),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(low))),3,pos(coreExt_assumedInfectiousWithProb(low))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),neg(coreExt_assumedInfectiousWithProb(low))),2,prev_pos(coreExt_assumedInfectiousWithProb(low))).
newbody(ifsThen((prev_pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),neg(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),neg(coreExt_assumedInfectiousWithProb(med))),1,prev_pos(coreExt_assumedInfectiousWithProb(med))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(low)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(low))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),1,pos(coreExt_assumedInfectiousWithProb(low))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_guidanceRequiresClearanceAfterAssumedInfectious(med))),pos(coreExt_assumedInfectiousWithDiseaseAwaitingClearance)),1,pos(coreExt_assumedInfectiousWithProb(med))).
newbody(ifsThen((pos(initialized(feature(tempCheck_recentlyFevered))),pos(tempCheck_recentlyFevered),pos(core_assumedInfectiousWithDisease)),pos(feature(tempCheck_recentlyFevered))),2,pos(tempCheck_recentlyFevered)).
newbody(ifsThen((pos(initialized(feature(tempCheck_recentlyFevered))),pos(tempCheck_recentlyFevered),pos(core_assumedInfectiousWithDisease)),pos(feature(tempCheck_recentlyFevered))),3,pos(initialized(feature(tempCheck_recentlyFevered)))).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_assumedInfectiousWithProb(low))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),1,pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))))).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)),pos(coreExt_assumedInfectiousWithProb(low))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low)))),2,pos(coreExt_assumedInfectiousWithProb(low))).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_assumedInfectiousWithProb(med))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),1,pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))))).
newbody(ifsThen((pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)),pos(coreExt_assumedInfectiousWithProb(med))),pos(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med)))),3,pos(coreExt_assumedInfectiousWithProb(med))).
newbody(ifsThen((pos(coreExt_assumedInfectiousWithProb(med)),neg(coreExt_assumedInfectiousWithProb(high))),pos(coreExt_needsGuidanceForAssumedInfectiousWithProb(med))),2,pos(coreExt_assumedInfectiousWithProb(med))).
newbody(ifsThen((pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbHighParam),pos(testing_needsNegTests(high))),pos(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))),1,pos(testing_guidanceRequiresNegativeTestsForAssumedInfectiousWithProbHighParam)).
newbody(ifsThen((pos(coreExt_mayBeCleared),clearance_cpUserCanClearBadStatesParam),pos(cpreq(show(clearance_mayBeCleared)))),1,clearance_cpUserCanClearBadStatesParam).
newbody(ifThen(pos(core_atHighRiskIfInfectedWithDisease),pos(core_notReadyToReturn)),1,pos(core_atHighRiskIfInfectedWithDisease)).
newbody(ifThen(pos(symptomsSurvey_fever),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_fever)).
newbody(ifThen(pos(symptomsSurvey_soreThroat),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_soreThroat)).
newbody(ifThen(pos(symptomsSurvey_cough),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_cough)).
newbody(ifThen(pos(symptomsSurvey_lossOfSmell),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_lossOfSmell)).
newbody(ifThen(pos(symptomsSurvey_difficultyBreathing),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_difficultyBreathing)).
newbody(ifThen(pos(symptomsSurvey_nausea),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_nausea)).
newbody(ifThen(pos(symptomsSurvey_diarrhea),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_diarrhea)).
newbody(ifThen(pos(symptomsSurvey_vomiting),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_vomiting)).
newbody(ifThen(pos(symptomsSurvey_headache),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_headache)).
newbody(ifThen(pos(symptomsSurvey_fatigue),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_fatigue)).
newbody(ifThen(pos(symptomsSurvey_muscleAches),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_muscleAches)).
newbody(ifThen(pos(symptomsSurvey_fluSymptoms),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_fluSymptoms)).
newbody(ifThen(pos(symptomsSurvey_unusualBruising),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsSurvey_unusualBruising)).
newbody(ifThen(pos(symptomsWhileSickSurvey_fever),pos(symptomsSurvey_surveyReportsSymptoms)),1,pos(symptomsWhileSickSurvey_fever)).
newbody(ifThen(neg(symptomsWhileSickSurvey_improvingSymptoms),pos(symptomsSurvey_surveyReportsSymptoms)),1,neg(symptomsWhileSickSurvey_improvingSymptoms)).
newbody(ifThen(pos(symptomsSurvey_surveyReportsSymptoms),pos(cpreq(reset(symptomsSurvey_symptomsSurvey)))),1,pos(symptomsSurvey_surveyReportsSymptoms)).
newbody(ifThen(pos(tempCheck_fever),pos(symptoms_symptomaticPos)),1,pos(tempCheck_fever)).
newbody(ifThen(pos(exposureSurvey_closeContact_covid),pos(exposureSurvey_surveyReportsExposure)),1,pos(exposureSurvey_closeContact_covid)).
newbody(ifThen(pos(exposureSurvey_intlTravel),pos(exposureSurvey_surveyReportsExposure)),1,pos(exposureSurvey_intlTravel)).
newbody(ifThen(pos(exposureSurvey_closeContact_intlTravel),pos(exposureSurvey_surveyReportsExposure)),1,pos(exposureSurvey_closeContact_intlTravel)).
newbody(ifThen(pos(exposureSurvey_highRiskTravel),pos(exposureSurvey_surveyReportsExposure)),1,pos(exposureSurvey_highRiskTravel)).
newbody(ifThen(pos(exposureSurvey_surveyReportsExposure),pos(cpreq(reset(exposureSurvey_exposureSurvey)))),1,pos(exposureSurvey_surveyReportsExposure)).
newbody(ifThen(pos(coreExt_cleared),neg(testing_posTestPos)),1,pos(coreExt_cleared)).
newbody(ifThen(pos(coreExt_cleared),pos(testing_posTestNeg)),1,pos(coreExt_cleared)).
newbody(ifThen(pos(testingWhileSickSurvey_receivedNegativeTests),neg(testing_needsNegTests(low))),1,pos(testingWhileSickSurvey_receivedNegativeTests)).
newbody(ifThen(pos(testingWhileSickSurvey_receivedNegativeTests),neg(testing_needsNegTests(med))),1,pos(testingWhileSickSurvey_receivedNegativeTests)).
newbody(ifThen(pos(testingWhileSickSurvey_receivedNegativeTests),neg(testing_needsNegTests(high))),1,pos(testingWhileSickSurvey_receivedNegativeTests)).
newbody(ifThen(pos(symptomsSurvey_surveyReportsSymptoms),pos(symptoms_symptomaticPos)),1,pos(symptomsSurvey_surveyReportsSymptoms)).
newbody(ifThen(pos(symptomsSurvey_fever),pos(symptoms_feverishPos)),1,pos(symptomsSurvey_fever)).
newbody(ifThen(pos(symptomsWhileSickSurvey_fever),pos(symptoms_feverishPos)),1,pos(symptomsWhileSickSurvey_fever)).
newbody(ifThen(pos(tempCheck_fever),pos(symptoms_feverishPos)),1,pos(tempCheck_fever)).
newbody(ifThen(pos(tempCheck_fever),pos(tempCheck_recentlyFevered)),1,pos(tempCheck_fever)).
newbody(ifThen(pos(exposureSurvey_surveyReportsExposure),pos(exposure_exposedPos)),1,pos(exposureSurvey_surveyReportsExposure)).
newbody(ifThen(pos(clearance_clearanceReceived),pos(coreExt_cleared)),1,pos(clearance_clearanceReceived)).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(low)),pos(core_assumedInfectiousWithDisease)),1,pos(coreExt_assumedInfectiousWithProb(low))).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(med)),pos(core_assumedInfectiousWithDisease)),1,pos(coreExt_assumedInfectiousWithProb(med))).
newbody(ifThen(pos(coreExt_cleared),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))),1,pos(coreExt_cleared)).
newbody(ifThen(pos(coreExt_cleared),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))),1,pos(coreExt_cleared)).
newbody(ifThen(pos(coreExt_cleared),neg(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(high))),1,pos(coreExt_cleared)).
newbody(ifThen(pos(symptomsSurvey_symptomsWhileSickSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsSurvey)))),1,pos(symptomsSurvey_symptomsWhileSickSurveyCompleted)).
newbody(ifThen(pos(testingSurvey_testingWhileSickSurveyCompleted),neg(uireq(show(testingSurvey_testingSurvey)))),1,pos(testingSurvey_testingWhileSickSurveyCompleted)).
newbody(ifThen(pos(symptomsSurvey_symptomsWhileSickSurveyCompleted),neg(uireq(show(symptomsSurvey_symptomsWhileSickSurvey)))),1,pos(symptomsSurvey_symptomsWhileSickSurveyCompleted)).
newbody(ifThen(pos(testingSurvey_testingWhileSickSurveyCompleted),neg(uireq(show(testingSurvey_testingWhileSickSurvey)))),1,pos(testingSurvey_testingWhileSickSurveyCompleted)).
newbody(ifThen(pos(tempCheck_fever),pos(initialized(feature(tempCheck_recentlyFevered)))),1,pos(tempCheck_fever)).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(low)),pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(low))))),1,pos(coreExt_assumedInfectiousWithProb(low))).
newbody(ifThen(pos(coreExt_assumedInfectiousWithProb(med)),pos(initialized(feature(coreExt_guidanceIncompleteAfterAssumedInfectiousWithProb(med))))),1,pos(coreExt_assumedInfectiousWithProb(med))).
newbody(ifThen(pos(coreExt_cleared),pos(core_nothingOfConcern)),1,pos(coreExt_cleared)).


% ?- behaves_inertially(testing_posTestNeg,121).