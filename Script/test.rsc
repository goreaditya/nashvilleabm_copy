Macro "SetParameters" (Args)
	// Set highway, transit, daysim, and airport parameters
    //RunMacro("SetTransitParameters", Args)
    RunMacro("SetHighwayParameters", Args)
    RunMacro("SetDaySimParameters", Args)
	RunMacro("SetAirportParameter")
endMacro

Macro "ConverSkimsToOMX" (Args)
	shared Scen_Dir, OutDir
	shared DaySimDir, Periods, iteration

	auto_modes = {"sov", "hov"}
	transit_modes = {"Local", "ExpBus", "Brt", "UrbRail", "ComRail"}
	transit_access = {"Walk", "Drive"}
	
	matrix_name = "hwyskim_ff"
	RunMacro("ExportToOMX", "auto" ,matrix_name, "Length", OutDir, OutDir)

	
	for p=1 to Periods.length do
		for m=1 to auto_modes.length do
			matrix_name = "hwyskim_" + Lower(Periods[p]) + "_" + auto_modes[m]
			RunMacro("ExportToOMX", "auto", matrix_name, "Length", OutDir, OutDir)
		end
		
		for m=1 to transit_modes.length do
			for a=1 to transit_access.length do
				matrix_name = Periods[p] + "_" + transit_access[a] + transit_modes[m] + "Skim" 
				RunMacro("ExportToOMX", "transit", matrix_name, "Generalized Cost", OutDir, OutDir)
			end
		end
	end

endMacro

Macro "ExportToOMX" (mode, mat, core, inDir, outDir)

    m = OpenMatrix(inDir + mat + ".mtx", )
	
	if mode="auto" then do
		mc = CreateMatrixCurrency(m,core,"Origin","Destination",)
	end
	else do
		mc = CreateMatrixCurrency(m,core,,,)
    end
	
	CopyMatrix(mc, {
        {"File Name", outDir + mat + "_temp.omx"},
		{"Indices", "Current"},
        {"OMX", "True"}
      } 
    )

endMacro

Macro "Run OMX Re Export" (Args)
    shared Scen_Dir, OutDir, drive, loop
    shared DaySimDir

	/*
	PURPOSE:
	- Generate new OMX skims using R from TransCAD generated OMX files
 
	*/
	
	starttime = RunMacro("RuntimeLog", {"OMX Re Exprot", null})
	RunMacro("SetParameters", Args)
	
	path_info = SplitPath(Scen_Dir)
    drive = path_info[1]
	
	pos = Position(Scen_Dir, "2018") //TODO - remove hard coded folder name (2018)
	ModelDir = Left(Scen_Dir, pos-1)
	
	// script directory
	ScriptDir = ModelDir + "Script\\"
	
	// Launch R batch file
	command_line = "cmd /c " + drive + " && cd " + ScriptDir + " && run_convert_to_omx.cmd"
	
	status = RunProgram(command_line,{{"Maximize", "True"}})
	status = 0
	
	endtime = RunMacro("RuntimeLog", {"OMX Re Export", starttime})
	
	Return(1)

endMacro


Macro "Run Test" (Args)
    shared Scen_Dir, OutDir, loop
    shared DaySimDir, drive

/*
PURPOSE:
- Run ABM with fixed starting shadow prices

STEPS:
1. set daysim parameters
2. before the first loop, copy roster files to global outputs folder
3. before the first loop, copy starting shadow prices from DaySim root folder
4. before the first loop, create properties file for shadow price and full runs
4. run the first two iterations of DaySim for long term choice models (work and school) - to stabilize shadow prices
5. run the third iteration of DaySim for all models
6. copy the DaySim trip file (_trip.tsv) to global outputs folder
*/

	RunMacro("SetParameters", Args)
	RunMacro("ConverSkimsToOMX", Args) 
	//RunMacro("Run OMX Re Export", Args)
	
endMacro

Macro "SetHighwayParameters" (Args)
    shared Periods, TimePeriod
    
    Periods={"AM","MD","PM","OP"}  

/*
    // minutes from midnight
    //OP: 0-359
    //AM: 360-539
    //MD: 540-899
    //PM: 900-1139
    //OP: 1140-1439
*/    
    dim TimePeriod[4]

    TimePeriod[1] = {360,539,9999,9999}    //AM
    TimePeriod[2] = {540,899,9999,9999}    //MD
    TimePeriod[3] = {900,1139,9999,9999}   //PM    
    TimePeriod[4] = {1140,1439,0,359} 	   //OP       
    
endMacro

Macro "SetAirportParameter"
	shared Scen_Dir
	shared mc_hbo, mc_nhbw, mc_nhbo
	shared purposes, modes, purposesPeriod, AirPeriodFactors
		
    mc_hbo = Scen_Dir + "outputs\\mc_hbo.mtx"
    mc_nhbw = Scen_Dir + "outputs\\mc_nhbw.mtx"
    mc_nhbo = Scen_Dir + "outputs\\mc_nhbo.mtx"
    
    purposes = {"HBO","NHBW","NHBO"}
    modes = {"DA","SR2","SR3"}
		
    purposesPeriod = {"OP","OP","PK"}
	AirPeriodFactors = {0.5,0.5,0.5,0.5}  // corresponding to Periods = {"AM","MD","PM","OP"}, factors to distribute trips from PK and OP periods		
		
endMacro

Macro "SetDaySimParameters" (Args)
    shared Scen_Dir, OutDir, DaySimDir
    shared TripFileName, TourFileName, TazIndexFileName, TripTourFile, MaxZone
	
	Scen_Dir = "E:\\Projects\\Clients\\NashvilleMPO\\ModelUpdate2023\\Model\\Development\\ABM_TCAD8_TAZSPLIT\\2018\\"
	OutDir = Scen_Dir + "outputs\\"
    
    DaySimDir = Scen_Dir + "DaySim\\"
	TripFileName = "_trip"
	TourFileName = "_tour"
	TripTourFile = OutDir + "trip_tour.csv"
    MaxZone  = 3012  //TODO: get this from taz index file

endMacro
