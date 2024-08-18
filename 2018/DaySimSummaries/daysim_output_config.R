#DaySim Version - DelPhi or C#
dsVersion                                 = "C#"

dshhfile                                  = "../DaySim/outputs/_household.tsv"
dsperfile                                 = "../DaySim/outputs/_person.tsv"
dspdayfile                                = "../DaySim/outputs/_person_day.tsv"
dstourfile                                = "../DaySim/outputs/_tour.tsv"
dstripfile                                = "../DaySim/outputs/_trip.tsv"

# Nashville Survey
surveyhhfile                              = "./data/nash_hrecx_rewt.dat"
surveyperfile                             = "./data/nash_precx_rewt.dat"
surveypdayfile                            = "./data/nash_pdayx.dat"
surveytourfile                            = "./data/nash_tourx.dat"
surveytripfile                            = "./data/nash_tripx.dat"

tazcountycorr                             = "./data/county_districts_nash.csv"

wrklocmodelfile                           = "./templates/WrkLocation.csv"
schlocmodelfile                           = "./templates/SchLocation.csv"
vehavmodelfile                            = "./templates/VehAvailability.csv"
daypatmodelfile1                          = "./templates/DayPattern_pday.csv"
daypatmodelfile2                          = "./templates/DayPattern_tour.csv"
daypatmodelfile3                          = "./templates/DayPattern_trip.csv"
tourdestmodelfile                         = "./templates/TourDestination.csv"
tourdestwkbmodelfile                      = "./templates/TourDestination_wkbased.csv"
tripdestmodelfile                         = "./templates/TripDestination.csv"
tourmodemodelfile                         = "./templates/TourMode.csv"
tourtodmodelfile                          = "./templates/TourTOD.csv"
tripmodemodelfile                         = "./templates/TripMode.csv"
triptodmodelfile                          = "./templates/TripTOD.csv"

wrklocmodelout                            = "WrkLocation.xlsm"
schlocmodelout                            = "SchLocation.xlsm"
vehavmodelout                             = "VehAvailability.xlsm"
daypatmodelout                            = "DayPattern.xlsm"
tourdestmodelout                          = c("TourDestination_Escort.xlsm","TourDestination_PerBus.xlsm","TourDestination_Shop.xlsm",
                                              "TourDestination_Meal.xlsm","TourDestination_SocRec.xlsm")
tourdestmodelout_fresno                   = c("TourDestination_Maintenance.xlsm","TourDestination_Discretionary.xlsm")											  
tourdestwkbmodelout                       = "TourDestination_WrkBased.xlsm"
tourmodemodelout                          = "TourMode.xlsm"
tourtodmodelout                           = "TourTOD.xlsm"
tripmodemodelout                          = "TripMode.xlsm"
triptodmodelout                           = "TripTOD.xlsm"

outputsDir                                = "./output"
validationDir                             = ""

prepSurvey                                = TRUE
prepDaySim                                = TRUE

runWrkSchLocationChoice                   = TRUE
runVehAvailability                        = TRUE
runDayPattern                             = TRUE
runTourDestination                        = TRUE
runTourMode                               = TRUE
runTourTOD                                = TRUE
runTripMode                               = TRUE
runTripTOD                                = TRUE

excludeChildren5                          = TRUE
tourAdj                                   = FALSE
tourAdjFile				                        = "./data/peradjfac.csv"