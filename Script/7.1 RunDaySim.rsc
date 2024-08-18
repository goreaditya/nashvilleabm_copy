//**************************************
//*					Run DaySim and Format DaySim Outputs					 *
//**************************************
// Author: nagendra.dhakar@rsginc.com
// Updated: 10/29/2015

/*
Script contains following macros that are used in the model

1. Run DaySim - three iterations of DaySim
2. Run DaySim Summaries - only in the last feedback loop
3. FormatAssignmentInputs - formats _trip.tsv into highway and transit od trip matrices

*/

Macro "SetParameters" (Args)
		// Set highway, transit, daysim, and airport parameters
    RunMacro("SetTransitParameters", Args)
    RunMacro("SetHighwayParameters", Args)
    RunMacro("SetDaySimParameters", Args)
	RunMacro("SetAirportParameter")
endMacro

Macro "ConverSkimsToOMX" (Args)
	shared Scen_Dir, OutDir, loop
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
	RunMacro("HwycadLog", {"Runing OMX Re Export in feedback loop " + i2s(loop), null})
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


Macro "Run DaySim" (Args)
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

	RunMacro("HwycadLog", {"7.1 RunDaySim.rsc", "  ****** Run DaySim ****** "})
	RunMacro("SetParameters", Args)
	RunMacro("ConverSkimsToOMX", Args) 
	RunMacro("Run OMX Re Export", Args)
    
    // number of daysim iterations
	//removed shadow pricing runs as districts constants are used in work location. stable shadow prices are used as inputs
    itercount = 1
    
    path_info = SplitPath(Scen_Dir)
    drive = path_info[1]

	RunMacro("HwycadLog", {"Copy DaySim inputs in feedback loop " + i2s(loop), null})
	
	// copy roster file to outputs folder
	infile = DaySimDir + "inputs\\nashville-roster_matrix_omx.csv"
	outfile = OutDir + "nashville-roster_matrix_omx.csv"
	CopyFile(infile,outfile)
	
	// copy roster combination file to outputs folder
	infile = DaySimDir + "inputs\\nashville_roster.combinations.csv"
	outfile = OutDir + "nashville_roster.combinations.csv"
	CopyFile(infile,outfile)    

	// copy shadow_prices.txt to working folder
	infile = DaySimDir + "inputs\\shadow_prices.txt"
	file_info = GetFileInfo(infile)
	if file_info != null then do
		outfile = DaySimDir + "working\\shadow_prices.txt"
		CopyFile(infile,outfile) 
	end

	// copy park_and_ride_shadow_prices.txt to working folder
	infile = DaySimDir + "inputs\\park_and_ride_shadow_prices.txt"
	file_info = GetFileInfo(infile)
	if file_info != null then do
		outfile = DaySimDir + "working\\park_and_ride_shadow_prices.txt"
		CopyFile(infile,outfile) 
	end
    
    if loop=1 then do
		
		// create properties file
		properties_template = DaySimDir + "Configuration_template.properties"
		properties_full = DaySimDir + "Configuration_full.properties"
		properties_shadow_price = DaySimDir + "Configuration_shadow_price.properties"
		
		fptr = OpenFile(properties_template, "r")
		
		ptr1 = OpenFile(properties_full, "w")
		ptr2 = OpenFile(properties_shadow_price, "w")
		
		while not FileAtEOF(fptr) do
			line = ReadLine(fptr)
			
			line_full = Substitute(line, "{ScenarioPath}", Scen_Dir,)
			line_sp = Substitute(line, "{ScenarioPath}", Scen_Dir,)

			line_full = Substitute(line_full, "{RunAll}", "true",)
			line_sp = Substitute(line_sp, "{RunAll}", "false",)			
		
			//full run
			WriteLine(ptr1, line_full)
			
			//shadow price
			WriteLine(ptr2, line_sp)

		end
		
		//close files
		CloseFile(fptr)
		CloseFile(ptr1)
		CloseFile(ptr2)
		
    end

    for i=1 to itercount do
		starttime = RunMacro("RuntimeLog", {"DaySim Iteration " + i2s(i) + " in feedback loop " + i2s(loop), null})
        if i=itercount then do
            config_file = "Configuration_full.properties"
        end
        else do
            config_file = "Configuration_shadow_price.properties"
        end

        // Launch Daysim
		RunMacro("HwycadLog", {"Runing DaySim for iteration " + i2s(i) + " in feedback loop " + i2s(loop), null})
        command_line = "cmd /c " + drive + " && cd " + DaySimDir + " && software\\Daysim.exe -c " + config_file
		//command_line = "cmd /c " + drive + " && cd " + " && E:\\Projects\\Clients\\NashvilleMPO\\ModelUpdate2023\\Tasks\\Task2_UpdateSoftware\\" + " && DaySim_exe_08152023\\Daysim.exe -c " + config_file 
        status = RunProgram(command_line,{{"Maximize", "True"}})
		
		endtime = RunMacro("RuntimeLog", {"DaySim Iteration " + i2s(i), starttime})
        
    end
	
    status = 0
		
	Return(1)

endMacro

Macro "Copy DaySim Outputs" (Args)
	shared OutDir, DaySimDir
	shared TripFileName, TourFileName
	
    // copy _trip.tsv and _tour.tsv files to global output directory 
    infile = DaySimDir + "outputs\\" + TripFileName + ".tsv"
    outfile = OutDir + TripFileName + ".csv"
    CopyFile(infile,outfile)
	
    infile = DaySimDir + "outputs\\" + TourFileName + ".tsv"
    outfile = OutDir + TourFileName + ".csv"
    CopyFile(infile,outfile)	

endMacro

Macro "Run DaySim Summaries" (Args)
    shared Scen_Dir, OutDir, drive, loop
    shared DaySimDir

	/*
	PURPOSE:
	- Generate summaries from DaySim outputs

	STEPS:
	1. set daysim parameters
	2. run R program to generate DaySim summaries - used only in final loop
	*/
	starttime = RunMacro("RuntimeLog", {"DaySim Summaries", null})
	RunMacro("HwycadLog", {"Runing DaySim Summaries in feedback loop " + i2s(loop), null})
    RunMacro("SetParameters", Args)

	path_info = SplitPath(Scen_Dir)
	drive = path_info[1]
	
	// set to outputs in scenario directory
	DaySimSumDir = Scen_Dir + "DaySimSummaries\\"

	// Launch Daysim
	command_line = "cmd /c " + drive + " && cd " + DaySimSumDir + " && daysim_summaries.cmd"
	
	status = RunProgram(command_line,{{"Maximize", "True"}})
	status = 0
	
	endtime = RunMacro("RuntimeLog", {"DaySim Summaries", starttime})
	
	Return(1)

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
    
    DaySimDir = Scen_Dir + "DaySim\\"
	TripFileName = "_trip"
	TourFileName = "_tour"
	TazIndexFileName = Args.[taz_index] //"nashville_taz_index_2018.csv"
	TripTourFile = OutDir + "trip_tour.csv"
    MaxZone  = 3012  //TODO: get this from taz index file

endMacro

Macro "JoinDaySimTripTourFiles"
    shared OutDir
    shared TripFileName, TourFileName, TripTourFile
	
	TripFile = OutDir + TripFileName + ".csv"
	TourFile = OutDir + TourFileName + ".csv"
	
	tripfile_view = OpenTable("triptable","CSV",{TripFile,})
	tourfile_view = OpenTable("tourtable","CSV",{TourFile,})
		
	joinedview = JoinViews("joined", tripfile_view+".tour_id",tourfile_view+".id",)
	view_set = joinedview + "|"
	
	//export joined view - include only selected fields 
	ExportView(view_set, "CSV", TripTourFile,{"half","otaz","dtaz","mode","pathtype","deptm","arrtm","trexpfac","tmodetp"},{{"CSV Header", "True"}})
	
	CloseView(tripfile_view)
	CloseView(tourfile_view)
	CloseView(joinedview)
	
endMacro

Macro "FormatAssignmentInputs" (Args)

    shared OutDir, DaySimDir, TripTourFile, Periods, TimePeriod, MaxZone, AccessAssgnModes
	shared TripRecords, TimePeriod, ArrayTrips, ArrayTransitTrips, Highway, Transit, TazIndexFileName

	/*
	PURPOSE:
	- Format DaySim trip file (_trip.tsv) into TransCAD matrices for highway and transit assignment

	STEPS:
	1. set highway and transit parameters
	2. read trip file (_trip.tsv) into an array
	3. segment the trip array into highway and transit OD trip arrays
	4. for each time period, create a trip matrix with required cores and fill corresponding trips
	5. free-up memory by setting arrays to null
	*/
	starttime = RunMacro("RuntimeLog", {"DaySim Trip Tables", null})
	RunMacro("HwycadLog", {"7.1 RunDaySim.rsc", " ******** Build DaySim Trip Matrices ******** "})
	RunMacro("SetParameters", Args)
	
	RunMacro("HwycadLog", {"Copying DaySim outputs", null})
	UpdateProgressBar("Copying DaySim outputs ... ", )
	RunMacro("Copy DaySim Outputs", Args)
	
	//join DaySim trip file and tour file
	RunMacro("HwycadLog", {"Joining trip and tour files", null})
	UpdateProgressBar("Joining trip and tour files ... ", )
	RunMacro("JoinDaySimTripTourFiles")

	Auto = True
	Transit = True

	// DAYSIM AUTO TABLE
	if (Auto) then do
		RunMacro("HwycadLog", {"Processing trips ... ", "Auto"})
		UpdateProgressBar("Processing auto trips ... ", )
		tripvw = OpenTable("tripvw", "CSV", {TripTourFile})

		//PCE trips
		tripPCE = CreateExpression(tripvw, "tripPCE", "if MODE = 3 then TREXPFAC*1 else if MODE = 4 then TREXPFAC*1/2  else if MODE = 5 then TREXPFAC*1/3.5  else if MODE = 6 then TREXPFAC*1 else 1*TREXPFAC", {"Integer", 1, 0})

		//Time of day
		trtime = CreateExpression(tripvw, "trtime", "if (HALF = 1) then ARRTM else DEPTM", {"Integer", 4, 0})
		rsgtod = CreateExpression(tripvw, "rsgtod", "if trtime >= 0 and trtime < 360 then 4 else if trtime >= 360 and trtime < 540 then 1 else if trtime >= 540 and trtime < 900 then 2 else if trtime >= 900 and trtime < 1140 then 3 else if trtime >= 1140 and trtime <= 1440 then 4" , {"Integer", 1, 0}) 

		//Define matrix core names	
		dim tripnames[17]
		tripnames = {"IICOM", "IISU", "IIMU","IEAUTO", "IESU", "EEAUTO", "EESU","Passenger_SOV","Passenger_HOV2","Passenger_HOV3","Commercial","SingleUnit","MU","Preload_MU", "Preload_SU", "Preload_Pass", "PersonTrips"}

		core01 = "if MODE = 3 then 'Passenger_SOV'"
		core02 = " else if MODE = 4 then 'Passenger_HOV2'"
		core03 = " else if MODE = 5 then 'Passenger_HOV3'"
		corestr = core01 + core02 + core03
		core_fld = CreateExpression(tripvw, "core_fld", corestr, {"String", 10, 0}) 

		//DaySim O/D TAZ fields
		{oTAZ, dTAZ} = {"otaz", "dtaz"}
		tazfile = TazIndexFileName
		tazvw = OpenTable("tazname", "CSV", {tazfile},)
		tazinfo = GetTableStructure(tazvw)
		tazIDfield = tazinfo[1][1]
			
		//Match field to matrix core (core_fld) & fill values (tripPCE) ; Matrix Made Easy!
		for todloop = 1 to Periods.Length do
			RunMacro("HwycadLog", {"Processing trips for: ", Periods[todloop]})
			UpdateProgressBar("Processing trips for: " + Periods[todloop], )
			outMat = OutDir + Periods[todloop]+"OD.mtx"

			//Create OD matrix & fill 0s
			triptable = CreateMatrix({tazvw+"|",tazvw+"."+tazIDfield, "Rows"},{tazvw+"|",tazvw+"."+tazIDfield, "Cols"}, {{"File Name", outMat}, {"Label", "DaySim_Trips"},{"Tables", tripnames} })
			tripmc = CreateMatrixCurrencies(triptable, null, null, null)
			for ft = 1 to tripmc.length do FillMatrix(tripmc[ft][2], null, null, {"Copy", 0}, ) end

			//SOV
			SetView(tripvw)
			numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 3) and rsgtod = "+i2s(todloop), )
			UpdateMatrixFromView(triptable, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})

			//HOV2
			numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 4) and rsgtod = "+i2s(todloop), )
			UpdateMatrixFromView(triptable, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})
			
			//HOV3+
			numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 5) and rsgtod = "+i2s(todloop), )
			UpdateMatrixFromView(triptable, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {tripPCE}, "Add", {{"Missing is zero", "Yes"}})

			DeleteSet("sel")

			tripmc.PersonTrips := 1*tripmc.Passenger_SOV + 2*tripmc.Passenger_HOV2 + 3.5*tripmc.Passenger_HOV3

		end
		
		CloseView(tazvw)
		arr = GetExpressions(tripvw)
		for i = 1 to arr.length do DestroyExpression(tripvw+"."+arr[i]) end
		CloseView(tripvw)
	end

	//DAYSIM TRANSIT TABLE
	if (Transit) then do
		RunMacro("HwycadLog", {"Processing trips ... ", "Transit"})
		//Expand Trips
		tripvw = OpenTable("tripvw", "CSV", {TripTourFile})
		factrips = CreateExpression(tripvw, "factrips", "if MODE = 6 then TREXPFAC*1 else 0", {"Integer", 1, 0})

		//Time of Day
		trtime = CreateExpression(tripvw, "trtime", "if (HALF = 1) then ARRTM else DEPTM", {"Integer", 4, 0})  //causing problems with commute rail. some trips are in MD and OP and aren't being assigned
		//trtime = CreateExpression(tripvw, "trtime", " 0.5*(DEPTM + ARRTM)", {"Integer", 4, 0}) //didn't work
		rsgtod = CreateExpression(tripvw, "rsgtod", "if trtime >= 0 and trtime < 360 then 4 else if trtime >= 360 and trtime < 540 then 1 else if trtime >= 540 and trtime < 900 then 2 else if trtime >= 900 and trtime < 1140 then 3 else if trtime >= 1140 and trtime <= 1440 then 4" , {"Integer", 1, 0}) 

		core01= " if TMODETP = 6 and PATHTYPE = 3 then 'WLKLOCBUS'"
		core02= " else if TMODETP = 6 and PATHTYPE = 4 then 'WLKURBRAIL'"
		core03= " else if TMODETP = 6 and PATHTYPE = 5 then 'WLKEXPBUS'"
		core04= " else if TMODETP = 6 and PATHTYPE = 6 then 'WLKCOMRAIL'"
		core05= " else if TMODETP = 6 and PATHTYPE = 7 then 'WLKBRT'"
		core06= " else if TMODETP = 7 and PATHTYPE = 3 then 'PNRLOCBUS'"
		core07= " else if TMODETP = 7 and PATHTYPE = 4 then 'PNRURBRAIL'"
		core08= " else if TMODETP = 7 and PATHTYPE = 5 then 'PNREXPBUS'"
		core09= " else if TMODETP = 7 and PATHTYPE = 6 then 'PNRCOMRAIL'"
		core10= " else if TMODETP = 7 and PATHTYPE = 7 then 'PNRBRT'"

		corestr = core01 + core02 + core03 + core04 + core05 + core06 + core07 + core08 + core09 + core10
		core_fld = CreateExpression(tripvw, "core_fld", corestr, {"String", 10, 0}) 
				
		TransitModes = {"Local", "UrbRail", "ExpBus", "ComRail", "Brt"}
		tripnames = {"WLKLOCBUS", "WLKURBRAIL", "WLKEXPBUS", "WLKCOMRAIL", "WLKBRT", "PNRLOCBUS", "PNRBRT", "PNREXPBUS", "PNRURBRAIL", "PNRCOMRAIL", "KNRLOCBUS", "KNRBRT", "KNREXPBUS", "KNRURBRAIL", "KNRCOMRAIL"}		
		
		//DaySim O/D TAZ fields
		{oTAZ, dTAZ} = {"otaz", "dtaz"}
		tazfile = TazIndexFileName
		tazvw = OpenTable("tazname", "CSV", {tazfile},)
		tazinfo = GetTableStructure(tazvw)
		tazIDfield = tazinfo[1][1]
			
		//Match field to matrix core (core_fld) & fill values (tripPCE) ; Matrix Made Easy!
		for todloop = 1 to Periods.Length do
			RunMacro("HwycadLog", {"Processing trips trips for: ", Periods[todloop]})
			UpdateProgressBar("Processing transit trips for: " + Periods[todloop], )
			outMat = OutDir + Periods[todloop] + "TripsByMode.mtx"

			//Create OD matrix & fill 0s
			triptable = CreateMatrix({tazvw+"|",tazvw+"."+tazIDfield, "Rows"},{tazvw+"|",tazvw+"."+tazIDfield, "Cols"}, {{"File Name", outMat}, {"Label", "DaySim_Trips"},{"Tables", tripnames} })
			tripmc = CreateMatrixCurrencies(triptable, null, null, null)
			for ft = 1 to tripmc.length do FillMatrix(tripmc[ft][2], null, null, {"Copy", 0}, ) end

			//Transit
			SetView(tripvw)
			numsel = SelectByQuery("sel", "Several", "Select * where (MODE = 6) and rsgtod = "+i2s(todloop), )
			UpdateMatrixFromView(triptable, tripvw+"|sel", oTAZ, dTAZ, "core_fld", {factrips}, "Add", {{"Missing is zero", "Yes"}})

			DeleteSet("sel")

		end

		CloseView(tazvw)
		arr = GetExpressions(tripvw)
		for i = 1 to arr.length do DestroyExpression(tripvw+"."+arr[i]) end
		CloseView(tripvw)
		
		//for commuter rail trips - include all CR trips by adding MD to AM and OP to PM. CR is active only in AM and PM periods. This is an issue for PNR.
		RunMacro("UpdateComuterRailTrips")
		
	end
	
	endtime = RunMacro("RuntimeLog", {"DaySim Trip Tables", starttime})

	Return(1)
		
endMacro

Macro "Read Trips" (tod)
    shared TripRecords, TimePeriod, ArrayTrips, ArrayTransitTrips, Highway, Transit

	/*
	PURPOSE:
	- Save trips into highway and transit arrays with segmentation by sub-mode and origin and destination

	STEPS:
	1. Goes through each trip record
	2. Trip time is trip arriavl time if the trip is in first of the tour, otherwise trip deptarture time
	3. Identify time period of the trip, and then highway trip or transit trip
	4. for highway save in [da/sr2/sr3][origin][destination] - 3*2900*2900
	5. for transit save as [walk/pnr/knr by submode][origin][destination] - 15*2900*2900
	*/

    for rec=1 to TripRecords.Length do
				
		perc = RealToInt(100*(rec/TripRecords.Length)) // percentage completion
		UpdateProgressBar("Segmenting trips by time period and sub-mode: " + string(rec) + " of " + string(TripRecords.Length), perc)
				
        //split string - tab delimited
		values = ParseString(TripRecords[rec],",")
        //values = ParseString(TripRecords[rec],"\t")
        
		//with updated file - trip_tour
        Half = StringToInt(values[1]) // 1-outbound, 2-inbound
        OTaz = StringToInt(values[2])
        DTaz = StringToInt(values[3])
        Mode = StringToInt(values[4])
        PathType = StringToInt(values[5])
        DeptTime = StringToReal(values[6])
        ArrTime = StringToReal(values[7])
		TripExpFactor = StringToReal(values[8])
		TransitAccess = StringToInt(values[9]) //tmodetp - from tour file				
        Trip = 0
        
        if (Half = 1) then TripTime = ArrTime
        else TripTime = DeptTime
        
        if OTaz >0 then do

			if ((TripTime >= TimePeriod[tod][1] and TripTime <= TimePeriod[tod][2] ) or (TripTime >= TimePeriod[tod][3] and TripTime <= TimePeriod[tod][4])) then do
					
				if (Mode = 6 and PathType > 2) then do // transit trip
				
					if Transit = 1 then do
						Trip=TripExpFactor
						
						if (TransitAccess=6) then do //Walk Transit
							// subtract 2 as sub-transit starts at 3 (local bus)
							transit_index = PathType-2
						end
						else do //PNR Transit	
							if (PathType=3) then transit_index=6
							if (PathType=4) then transit_index=9
							if (PathType=5) then transit_index=8
							if (PathType=6) then transit_index=10
							if (PathType=7) then transit_index=7
						end											
						
						//No KNR currently
						
						ArrayTransitTrips[transit_index][OTaz][DTaz] = NullToZero(ArrayTransitTrips[transit_index][OTaz][DTaz]) + Trip                          
									 
					end
				end
						
				else do             // highway trip
					if Highway = 1 then do
						Trip = 0
						
						// person trip to vehicle trip factors: hov2 (2) and hov3+ (3.5)
						//SOV
						if (Mode = 3) then do
							Trip = TripExpFactor
							ArrayTrips[1][OTaz][DTaz] = NullToZero(ArrayTrips[1][OTaz][DTaz]) + Trip
							ArrayTrips[4][OTaz][DTaz] = NullToZero(ArrayTrips[4][OTaz][DTaz]) + 1
						end
						
						//HOV2
						if (Mode = 4) then do
							Trip = TripExpFactor/2
							ArrayTrips[2][OTaz][DTaz] = NullToZero(ArrayTrips[2][OTaz][DTaz]) + Trip
							ArrayTrips[4][OTaz][DTaz] = NullToZero(ArrayTrips[4][OTaz][DTaz]) + 1
						end                            

						//HOV3
						if (Mode = 5) then do
							Trip = TripExpFactor/3.5
							ArrayTrips[3][OTaz][DTaz] = NullToZero(ArrayTrips[3][OTaz][DTaz]) + Trip
							ArrayTrips[4][OTaz][DTaz] = NullToZero(ArrayTrips[4][OTaz][DTaz]) + 1
						end 

					end                         
				end
	
			end
    
        end
    end
     
endMacro

Macro "Fill Matrix" (OutDir, inMatFile, MaxZone, MatrixCore, ArrayValues)

    // open a matrix
    mat = OpenMatrix(OutDir + inMatFile, "True")
    
    // Create matrix currency
    mat_curr = CreateMatrixCurrency(mat, MatrixCore, "Rows", "Cols",)
    
    // create range of rows and cols
    dim rows_ind[MaxZone]
    dim cols_ind[MaxZone]
    
    for i=1 to MaxZone do
        rows_ind[i]=i
        cols_ind[i]=i
    end
    
    // set matrix values
    operation = {"Copy",ArrayValues}
    SetMatrixValues(mat_curr,rows_ind,cols_ind,operation,)
    
    // set null values to zero
    mat_curr := nz(mat_curr)
    
    // set matrix and currency to null
    mat=null
    mat_curr=null

endMacro


Macro "Create a new matrix" (OutDir, tazname, outMatFile, matrix_cores)

	mat = CreateMatrix({tazname +"|", tazname  + ".Zone_id", "Rows"},{tazname +"|", tazname  + ".Zone_id", "Cols"},
             {{"File Name", OutDir + outMatFile},{"Type","Float"},
             {"Tables", matrix_cores}})
			 
    // Loop by core
    for c = 1 to matrix_cores.length do
      mc_rev = CreateMatrixCurrency(mat, matrix_cores[c],"Rows","Cols",)
      mc_rev:=nz(mc_rev)
    end
    
    // null out the matrix and currency handles
    mc_rev = null
    mat  = null

endMacro

Macro "Fill Highway Airport Trips" (Args)
    shared Scen_Dir
	shared mc_hbo, mc_nhbw, mc_nhbo,purposes, modes 

	/*
	PURPOSE:
	- Add airport trips (post MC) to PA matrix

	STEPS:
	0. Set airport parameters
	1. for each of the three purposes, get the trips from airport model mode choice output and add to PA matrix
	*/

	RunMacro("SetParameters", Args)
		
    PA_Matrix=Args.[PA Matrix]

/*		
    mc_hbo = Scen_Dir + "outputs\\mc_hbo.mtx"
    mc_nhbw = Scen_Dir + "outputs\\mc_nhbw.mtx"
    mc_nhbo = Scen_Dir + "outputs\\mc_nhbo.mtx"
    
    purposes = {"HBO","NHBW","NHBO"}
    modes = {"DA","SR2","SR3"}
*/
    
    for p=1 to purposes.Length do
		
		perc = RealToInt(100*p/purposes.Length)
		UpdateProgressBar("Fill Airport Highway Trips: " + string(p) + " of " + string(purposes.Length), perc)
				
        for m=1 to modes.Length do
            core = purposes[p]+"_"+modes[m]
            
            RunMacro("TCB Init")
            
            mc1 = RunMacro("TCB Create Matrix Currency", PA_Matrix, core,,)
            
            if purposes[p] = "HBO" then do
                mc2 = RunMacro("TCB Create Matrix Currency", mc_hbo, modes[m],,)
            end
            
            if purposes[p] = "NHBW" then do
                mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbw, modes[m],,)
            end
            
            if purposes[p] = "NHBO" then do
                mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbo, modes[m],,)
            end 
            
            mc1 := nz(mc2)
            
        end
    end

endMacro

Macro "Fill Person Trips" (Args)
    shared Scen_Dir, loop

	/*
	PURPOSE:
	- Fill daysim person trips to PA matrix - for MOE generation process

	STEPS:
	0. Set airport parameters
	1. For each time period, access DaySim person trip core in the temp OD matrix created in "FormatAssignmentInputs" macro.
	2. If loop is after first, then delete "DaySimPersonTrips" core and add a new one
	3. add the aggregated trips from all time periods
	*/

	UpdateProgressBar("Fill DaySim Person Trips to PA matrix" , )
		
    PA_Matrix=Args.[PA Matrix]

    //add daysim person trips
	OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}    

    // temp matrix
    //FileInfo = GetFileInfo(OD[1])
    //temp_am = Scen_Dir + "outputs\\temp_" + FileInfo[1]
    mc1 = RunMacro("TCB Create Matrix Currency", OD[1], "PersonTrips",,)
    
    //FileInfo = GetFileInfo(OD[2])
    //temp_md = Scen_Dir + "outputs\\temp_" + FileInfo[1]
    mc2 = RunMacro("TCB Create Matrix Currency", OD[2], "PersonTrips",,)

    //FileInfo = GetFileInfo(OD[3])
    //temp_pm = Scen_Dir + "outputs\\temp_" + FileInfo[1]
    mc3 = RunMacro("TCB Create Matrix Currency", OD[3], "PersonTrips",,)

    //FileInfo = GetFileInfo(OD[4])
    //temp_op = Scen_Dir + "outputs\\temp_" + FileInfo[1]
    mc4 = RunMacro("TCB Create Matrix Currency", OD[4], "PersonTrips",,)

    // add a core to PA matrix = "DaySimPersonTrips"
    m = OpenMatrix(PA_Matrix, )
		
	matrix_cores = GetMatrixCoreNames(m)
		
	for core=1 to matrix_cores.Length do
		if matrix_cores[core]="DaySimPersonTrips" then DropMatrixCore(m, "DaySimPersonTrips")
	end
    
    AddMatrixCore(m, "DaySimPersonTrips")
    mc5 = RunMacro("TCB Create Matrix Currency", PA_Matrix, "DaySimPersonTrips",,)
    
    // add all daysim person trips
    mc5 :=nz(mc1)+nz(mc2)+nz(mc3)+nz(mc4)    
    
endMacro

Macro "Fill Transit Airport Trips" (Args)
    shared Scen_Dir, OutDir, Modes, AccessAssgnModes, Periods // input files
	shared mc_hbo, mc_nhbw, mc_nhbo,purposes, purposesPeriod, AirPeriodFactors 

/*
PURPOSE:
- Add airport trips (post MC) to *TripsByMode matrices

STEPS:
0. Set airport parameters
1. for each of the three purposes, get transit trips from airport model mode choice output and add to PA matrix
2. transit assignment now include four time periods but airport model is still with two time periods, so use
	 factors to devide trips into four time periods
*/
		
		RunMacro("SetParameters", Args)

/*		
    mc_hbo = Scen_Dir + "outputs\\mc_hbo.mtx"
    mc_nhbw = Scen_Dir + "outputs\\mc_nhbw.mtx"
    mc_nhbo = Scen_Dir + "outputs\\mc_nhbo.mtx"
    
    purposes = {"HBO","NHBW","NHBO"}
    purposesPeriod = {"OP","OP","PK"}
	AirPeriodFactors = {0.5,0.5,0.5,0.5}  // corresponding to Periods = {"AM","MD","PM","OP"}, factors to distribute trips from PK and OP periods
*/
 
    for ipurp=1 to purposes.length do
		
		perc = RealToInt(100*ipurp/purposes.length)
		UpdateProgressBar("Fill Airport Highway Trips: " + string(ipurp) + " of " + string(purposes.length), perc)		
		
        for iacc=1 to AccessAssgnModes.length do
            for imode=1 to Modes.length do

				if (imode=1 & iacc=1) then tablename="WLKLOCBUS"
				if (imode=2 & iacc=1) then tablename="WLKBRT"
				if (imode=3 & iacc=1) then tablename="WLKEXPBUS"
				if (imode=4 & iacc=1) then tablename="WLKURBRAIL"
				if (imode=5 & iacc=1) then tablename="WLKCOMRAIL"
				if (imode=1 & iacc=2) then tablename="PNRLOCBUS"
				if (imode=2 & iacc=2) then tablename="PNRBRT"
				if (imode=3 & iacc=2) then tablename="PNREXPBUS"
				if (imode=4 & iacc=2) then tablename="PNRURBRAIL"
				if (imode=5 & iacc=2) then tablename="PNRCOMRAIL"
				if (imode=1 & iacc=3) then tablename="KNRLOCBUS"
				if (imode=2 & iacc=3) then tablename="KNRBRT"
				if (imode=3 & iacc=3) then tablename="KNREXPBUS"
				if (imode=4 & iacc=3) then tablename="KNRURBRAIL"
				if (imode=5 & iacc=3) then tablename="KNRCOMRAIL"
				
				RunMacro("TCB Init")
				
				if purposes[ipurp] = "HBO" then do
						mc2 = RunMacro("TCB Create Matrix Currency", mc_hbo, tablename,,)
				end
				
				if purposes[ipurp] = "NHBW" then do
						mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbw, tablename,,)
				end
				
				if purposes[ipurp] = "NHBO" then do
						mc2 = RunMacro("TCB Create Matrix Currency", mc_nhbo, tablename,,)
				end
				
				if (purposesPeriod[ipurp]="PK") then do
					//AM
					mc1 = RunMacro("TCB Create Matrix Currency", OutDir + Periods[1]+"TripsByMode.mtx", tablename,,)
					mc1 := nz(mc1) + AirPeriodFactors[1]*nz(mc2)
					//PM 																																																				// todo - transpose?
					mc3 = RunMacro("TCB Create Matrix Currency", OutDir + Periods[3]+"TripsByMode.mtx", tablename,,)
					mc3 := nz(mc3) + AirPeriodFactors[3]*nz(mc2)								
				end
				else do  //OP
					//MD
					mc1 = RunMacro("TCB Create Matrix Currency", OutDir + Periods[2]+"TripsByMode.mtx", tablename,,)
					mc1 := nz(mc1) + AirPeriodFactors[2]*nz(mc2)
					//OP
					mc3 = RunMacro("TCB Create Matrix Currency", OutDir + Periods[4]+"TripsByMode.mtx", tablename,,)
					mc3 := nz(mc3) + AirPeriodFactors[4]*nz(mc2)							
				
				end           

            end
        end 
    end

endMacro

Macro "UpdateComuterRailTrips" (Args)
    shared Scen_Dir, OutDir, Modes, AccessAssgnModes, Periods // input files
	shared mc_hbo, mc_nhbw, mc_nhbo,purposes, purposesPeriod, AirPeriodFactors 

/*
PURPOSE:
- Add MD trip to AM and OP trips to PM
*/
		
	RunMacro("SetParameters", Args)	
	tablenames = {"WLKCOMRAIL","PNRCOMRAIL","KNRCOMRAIL"}
	for i=1 to tablenames.length do	
		tablename = tablenames[i]
		RunMacro("TCB Init")
		//AM
		mc1 = RunMacro("TCB Create Matrix Currency", OutDir + "AMTripsByMode.mtx", tablename,,)
		mc2 = RunMacro("TCB Create Matrix Currency", OutDir + "MDTripsByMode.mtx", tablename,,)
		mc1 := nz(mc1) + nz(mc2)
		mc2 := 0
	
		//PM
		mc3 = RunMacro("TCB Create Matrix Currency", OutDir + "PMTripsByMode.mtx", tablename,,)
		mc4 = RunMacro("TCB Create Matrix Currency", OutDir + "OPTripsByMode.mtx", tablename,,)
		mc3 := nz(mc3) + nz(mc4)
		mc4 := 0
	end

endMacro