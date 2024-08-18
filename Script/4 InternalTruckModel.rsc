Macro "InternalTruckModel" (Args)
	
	
	starttime = RunMacro("RuntimeLog", {"Internal Truck Model", null})
	RunMacro("HwycadLog", {"4 InternalTruckModel.rsc", "Run Internal Truck and Commercial Vehicle Model"})

	RunMacro("Settings", Args)
	RunMacro("TCB Init")
	
	RunMacro("HwycadLog", {"Aggregate LandUse", null})
	ok = RunMacro("Aggregate_LU")
	if (ok<>1)then  goto quit
	
	RunMacro("HwycadLog", {"Calculate Accessibilities", null})
	ok = RunMacro("Accessibilities")
	if (ok<>1) then goto quit
	
	RunMacro("HwycadLog", {"Run Truck Model", null})
	ok = RunMacro("Truck_Model")
	if (ok<>1) then goto quit
	
	RunMacro("HwycadLog", {"Run Commercial Vehicle Model", null})
	ok = RunMacro("4TCV_Model")
	if (ok<>1) then goto quit
	
	RunMacro("HwycadLog", {"Run Trip Length Summaries", null})
	ok = RunMacro("Run_Summaries")
	if (ok<>1) then goto quit	
	
	RunMacro("HwycadLog", {"Close All Views", null})
	ok = RunMacro("CloseAllViews")
	if (ok<>1) then goto quit
	
	endtime = RunMacro("RuntimeLog", {"Internal Truck Model", starttime})
		
	quit:
		Return(ok)
endMacro

Macro "Settings" (Args)
	shared Scen_Dir, feedback_iteration
	shared path, skim_truck, skim_truck_time, network, network_db, hh_file, parcel_lu_file 
	shared od_trk, trk_pa_outfile, trk_balance_outfile, trk_gravity_outfile, hh_temp_file, taz_lu_temp_file, tazindex_file
	shared od_cv, cv_gen_outfile, cv_gravity_outfile, cv_balance_outfile

	//INPUTS
	path 				= Scen_Dir
	skim_truck 			= Args.[md skim]
	hh_file 			= Args.[Households]
	parcel_lu_file 		= Args.[Parcels]
	tazindex_file 		= Args.[taz_index]
	
	skim_truck_time 	= "Shortest Path - [time_MD_AB_time_MD_BA]"

	//OUTPUTS - TRUCKS (SU and MU)
	od_trk				= Args.[Internal Truck OD]
	
	//OUTPUTS - CV
	od_cv 				= Args.[CV OD]

	//Intermediate Outputs - Truck Model
	trk_pa_outfile 		= path + "outputs\\Truck_PA.bin"
	trk_balance_outfile = path + "outputs\\Balance.bin"
	trk_gravity_outfile = path + "outputs\\Truck_Gravity.mtx"
	hh_temp_file 		= path + "outputs\\household.csv"
	taz_lu_temp_file 	= path + "outputs\\taz_daysim.bin"
	cv_balance_outfile  = path + "outputs\\CV_Balance.bin"

	//Intermediate Outputs - CV Model
	cv_gen_outfile 		= path + "outputs\\CVTripGen.bin"
	cv_gravity_outfile 	= path + "outputs\\CV_Gravity.mtx"

endMacro

Macro "Aggregate_LU"
	shared parcel_lu_file, hh_file
	shared taz_lu_temp_file, hh_temp_file
	shared tazvec
	shared ID, BAS, IND, RET, SRVC, HH, TOTEMP, PRO, POP, SRV, FDL, OSV
	
	on error, notfound do
		goto quit
	end

	//read DaySim parcel file and aggregate data by TAZ
	parcel_lu_file_vw = OpenTable("parcel_lu_file_vw", "CSV", {parcel_lu_file},{{"Delimiter", " "}})
	tazvec = AggregateTable("tazvec", parcel_lu_file_vw+"|", "FFB", taz_lu_temp_file, "taz_p", {
		 {"hh_p","sum", },
		 {"empedu_p","sum", },
		 {"empfoo_p","sum", },
		 {"empind_p","sum", },
		 {"empgov_p","sum", },
		 {"empmed_p","sum", },
		 {"empsvc_p","sum", },
		 {"empret_p","sum", },
		 {"empoth_p","sum", },
		 {"empofc_p","sum", },
		 {"emptot_p","sum", }
		 }, null)
	
	//save zonal data as vectors	
	ID 				=   GetDataVector(tazvec+"|", "taz_p", )		
	BAS   			= 	GetDataVector(tazvec+"|", "empoth_p", )		
	IND 			= 	GetDataVector(tazvec+"|", "empind_p", )		
	RET 			= 	GetDataVector(tazvec+"|", "empret_p", )		
	HH 				=	GetDataVector(tazvec+"|", "hh_p", )			
	TOTEMP 			= 	GetDataVector(tazvec+"|", "emptot_p", )
	OFC 			=   GetDataVector(tazvec+"|", "empofc_p", )
	MED 			= 	GetDataVector(tazvec+"|", "empmed_p", )	
	GOV 			=   GetDataVector(tazvec+"|", "empgov_p", )
	EDU 			=   GetDataVector(tazvec+"|", "empedu_p", )
	SVC 			= 	GetDataVector(tazvec+"|", "empsvc_p", )
	FDL 			= 	GetDataVector(tazvec+"|", "empfoo_p", )
	PRO 			=   OFC + MED + GOV
	OSV 			= 	EDU + SVC
	SRVC 			=   PRO + OSV
	SRV 			= 	FDL + PRO + OSV

	//household and population data
	hhfile 		 = OpenTable("household", "CSV", {hh_file},{{"Delimiter", " "}})
	hhsize 	   	 = GetDataVector(hhfile+"|", "hhsize", )
	POP 	   	 = VectorStatistic(hhsize, "sum", )

	CloseView(hhfile)
	
	ok=1
	
	quit:
	Return(ok)

EndMacro

Macro "CalculateIntrazonal"(skim_mat, skim_name, value)
	
    mc = RunMacro("TCB Create Matrix Currency", skim_mat, skim_name, "TAZ_ID", "TAZ_ID")
    ok = (mc <> null)
    //if !ok then goto quit

    FillMatrix(mc,,, {"Copy", value}, {{"Diagonal", "Yes"}})		

endMacro

Macro "Accessibilities"
	shared tazvec, skim_truck, skim_truck_time
	shared POP, BAS, IND, RET, SRV, HH, FDL, OSV, PRO

	on error, notfound do
		goto quit
	end
	
	//set intrazonal to 0
	RunMacro("CalculateIntrazonal", skim_truck, "RiverX (Skim)", 0)
	
	//read skims
	impmat = OpenMatrix(skim_truck,)
	mcic = CreateMatrixCurrency(impmat, skim_truck_time, "TAZ_ID", "TAZ_ID", null)  //using "Shortest Path - _MSATimeMD" for generalized cost as no tolls in the region

	//regression equations
	GENATT  = POP + 0.6151*BAS + 0.8984*IND + 3.0097*RET + 1.8052*SRV
	NEARATT = 3.4111*RET + 2.7404*SRV
	OTHRATT = 0.2605*HH + 1.000*RET + 1.0452*FDL + 0.2720*OSV + 0.1710*PRO + 0.0804*BAS + 0.0061*IND

	list_views2 = GetViewNames()

	RunMacro("addfields", tazvec, {"GENATT","NEARATT","OTHRATT"}, {"r","r","r"})
	SetDataVectors(tazvec+"|", {{"GENATT",GENATT}, {"NEARATT",NEARATT}, {"OTHRATT",OTHRATT}}, {{"Sort Order",{{"taz_p","Ascending"}}}})

				 //sizes  , betas  ,  diff, imp  ,  outnames   ,modes
	accessarr = {{ GENATT , -0.1911, 0    , mcic , "GenAccess" , 1},
				 { NEARATT, -0.50  , 0    , mcic , "NearAccess", 1},
				 { EMP    , -0.13  , 0    , mcic , "AccessEMP" , 1},
				 { RET    , -0.18  , 0    , mcic , "AccessRET" , 1}
				}

	// Add a matrix core to the impedance matrix for accessibility calculations
	mca1 = RunMacro("CheckMatrixCore", impmat, "AccessCalc", "TAZ_ID", "TAZ_ID",) 

	// Loop over each accessibility measure
	mca = {mca1}
	set = {null}
	for i = 1 to accessarr.length do
	  {size, beta, diff, impx, outname, mode} = accessarr[i]
	  RunMacro("addfields", tazvec, {outname}, {"r"})
	  thismca = mca[mode]
	  thisset = set[mode]
	  
	  if diff = 0 then do thismca := size * exp(beta * impx) end
	  
	  rsv = GetMatrixVector(thismca, {{"Marginal", "Row Sum"}})
	  logsum = Max(0, Log(rsv))
	  SetDataVector(tazvec+"|"+thisset, outname, logsum, {{"Sort Order",{{"taz_p","Ascending"}}}})
	  
	  //Calculate GenAcc^2
	  if outname = "GenAccess" then do
		RunMacro("addfields", tazvec, {"GenAcc2"}, {"r"})
		GenAcc2 = -1*pow(logsum - 8.5,2)
		SetDataVector(tazvec+"|"+thisset, "GenAcc2", GenAcc2, {{"Sort Order",{{"taz_p","Ascending"}}}})
	  end
	  
	end

	RunMacro("dropfields", tazvec,{"NearAccess","AccessEMP","AccessRET"})
	
	ok=1
	
	quit:
	Return(ok)

EndMacro

Macro "Truck_Model"
	shared path, skim_truck, skim_truck_time, network, network_db, hh_file , tazindex_file
	shared tazvec
	shared od_trk, trk_pa_outfile, trk_balance_outfile, trk_gravity_outfile, hh_temp_file
	shared ID, BAS, IND, RET, SRVC, HH, TOTEMP, PRO 

	GenAccess 		=   GetDataVector(tazvec+"|", "GenAccess", )
	
	//Generation
	SUT_Gen = 0.9830*BAS + 2.4290*IND + 1.6000*RET + 0.3000*SRVC + 0.0080*HH 
	MUT_Gen = TOTEMP * 0.1276 - PRO * 0.1177 + IND * 0.0823

	//Pseudo II Split - borrowed from Chattanooga. TODO: Calibrate for Nashville (based on shares from native process)
	//chattanooga = 0.1601 for SUT and 0.0782 for MUT
	//II_SUT_Gen = 0.1601 * SUT_Gen
	//II_MUT_Gen = 0.0782 * MUT_Gen
	II_SUT_Gen = 0.075 * SUT_Gen
	II_MUT_Gen = 0.91* MUT_Gen
	
	//Distribution
	//Create PA table
	trkpavw = CreateTable("trkpa"  , trk_pa_outfile,"FFB", 
					{   {"ID"     , "Integer", 10  , null, "No"},
						{"SU_Trks" , "Integer", 10  , 3   , "No"}, 
						{"MU_Trks" , "Integer", 10  , 3   , "No"},
						{"II_SUT_O", "Real"   , 8   , 3   , "No"}, 
						{"II_SUT_D", "Real"   , 8   , 3   , "No"}, 
						{"II_MUT_O", "Real"   , 8   , 3   , "No"}, 
						{"II_MUT_D", "Real"   , 8   , 3   , "No"}					
					})

	linecount = VectorStatistic(ID, "Count", )
	r = AddRecords(trkpavw, null, null, {{"Empty Records", linecount}})

	SetDataVectors(trkpavw + "|", {{"ID",ID}, {"SU_Trks",SUT_Gen}, {"MU_Trks",MUT_Gen}, 
									{"II_SUT_O",II_SUT_Gen}, {"II_SUT_D",II_SUT_Gen}, 
									{"II_MUT_O",II_MUT_Gen}, {"II_MUT_D",II_MUT_Gen}
								}, {{"Sort Order",{{"ID","Ascending"}}}}) 

	// ----- BALANCING ------
	 
	Opts = null
    Opts.Input.[Data View Set] = {trk_pa_outfile, trkpavw}
    Opts.Field.[Vector 1] = {"II_SUT_O", "II_MUT_O"}
    Opts.Field.[Vector 2] = {"II_SUT_D", "II_MUT_D"}
    Opts.Global.[Output Type] = "WRITE"
    Opts.Global.[Store Type] = "Real"
    Opts.Output.[Output Table] = trk_balance_outfile

    ok = RunMacro("TCB Run Procedure", "Balance", Opts)
	 
	// ----- TRUCK TRIP DISTRIBUTION ------
     // Create K factor matrices for OD portion of utilities (except straight impedance)        
	kmat = OpenMatrix(skim_truck, )
	 
	//River Crossing
	mcriv = RunMacro("CheckMatrixCore", kmat, "RiverX (Skim)", "TAZ_ID", "TAZ_ID",)
	mcriv := min(mcriv, 30) 
	//Intrazonal 1s
	mciz  = RunMacro("CheckMatrixCore", kmat, "IZ", "TAZ_ID", "TAZ_ID",)
	mciz := 0     
	v1 = Vector(mciz.cols, "float", {{"Constant", 1}})
	SetMatrixVector(mciz, v1, {{"Diagonal"}})

	//k Factors for ISUT, IMUT
	mckIS = RunMacro("CheckMatrixCore", kmat, "kIS", "TAZ_ID", "TAZ_ID",)
	mckIM = RunMacro("CheckMatrixCore", kmat, "kIM", "TAZ_ID", "TAZ_ID",)
	
    // TAZ portion of utilities
    k_IS = exp(-0.4923*GenAccess)    //exp(-0.4923*GenAccess) - from Chattanooga
    k_IM = exp(-1.5682*GenAccess)

    // Exponentiated utilities (less any straight impedance component) by adding OD elements to TAZ component  
    mckIS := k_IS * exp(-0.8625*mcriv + -1.4781*mciz)                                                                                      
    mckIM := k_IM * exp(3.1263*mcriv  + -5.3620*mciz)

	//Run Gravity Model to get PAs
	//RunMacro("TCB Init")
	Opts = null
	Opts.Input.[PA View Set] = {trk_pa_outfile, trkpavw}
	Opts.Input.[FF Matrix Currencies] = {null, null}
	Opts.Input.[Imp Matrix Currencies] = { {skim_truck, skim_truck_time, "TAZ_ID", "TAZ_ID"}, {skim_truck, skim_truck_time, "TAZ_ID", "TAZ_ID"} }
    Opts.Input.[KF Matrix Currencies] = {{skim_truck, "kIS", "TAZ_ID", "TAZ_ID"}, {skim_truck, "kIM", "TAZ_ID", "TAZ_ID"}} 
	Opts.Field.[Prod Fields]      = {trkpavw+".II_SUT_O", trkpavw+".II_MUT_O"}
	Opts.Field.[Attr Fields]      = {trkpavw+".II_SUT_D", trkpavw+".II_MUT_D"}
	Opts.Global.[Purpose Names]   = {"II_SUT"           , "II_MUT"           }
	Opts.Global.Iterations        = {500                , 500                }
	Opts.Global.Convergence       = {0.001              , 0.001              }
	Opts.Global.[Constraint Type] = {"Double"           , "Double"           }
	Opts.Global.[Fric Factor Type]= {"Exponential"      , "Exponential"      }
	Opts.Global.[A List]          = {1                  , 1                  }
	Opts.Global.[B List]          = {0.3                , 0.3                }    
	Opts.Global.[C List]          = {0.005             , 0.0926             } //chattanooga - 0.9713 
	Opts.Flag.[Use K Factors]     = {1                  , 1                  }
	Opts.Flag.[Post Process] = "False"
	Opts.Output.[Output Matrix].Label = "Truck Trip Matrix"
	Opts.Output.[Output Matrix].Type = "Float"
	Opts.Output.[Output Matrix].[File based] = "FALSE"
	Opts.Output.[Output Matrix].Sparse = "False"
	Opts.Output.[Output Matrix].[Column Major] = "False"
	Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = trk_gravity_outfile

    ok = RunMacro("TCB Run Procedure", "Gravity", Opts)
    if !ok then Return(RunMacro("TCB Closing", ok, True))
	CloseView(trkpavw)

	//PA to OD by Averaging with Transpose	
	trkPA = OpenMatrix(trk_gravity_outfile,)
	tempmtx = GetTempFileName(".mtx")
	trktrans = TransposeMatrix(trkPA, {{"File Name", tempmtx}, {"Label", "Transpose"}, {"Type", "Double"}, {"Sparse", "No"}, {"Column Major", "No"}, {"File Based", "Yes"}, {"Compression", 1}}) 
	
	cnames = {"II_SUT", "II_MUT", "AM_SUT", "MD_SUT", "PM_SUT", "OP_SUT", "AM_MUT", "MD_MUT", "PM_MUT", "OP_MUT"}
	tazindex_vw = OpenTable("tazindex_vw", "CSV", {tazindex_file},)
	RunMacro("Create a new matrix", tazindex_vw, od_trk, cnames)
	
	//create a new index
	SetView(tazindex_vw)
	nsel = SelectByQuery("Internal", "Several", "Select * where Dest_eligible=1",)
	trkOD = OpenMatrix(od_trk,)
	new_index = CreateMatrixIndex("Internal", trkOD, "Both", tazindex_vw + "|Internal", "Zone_id", "Zone_id")
	CloseView(tazindex_vw)

	//SUT 
	mcIISUT = CreateMatrixCurrency(trkOD, "II_SUT", "Internal", "Internal", )
	mcPASUT = CreateMatrixCurrency(trkPA, "II_SUT", null, null, null)
	mcIISUT := mcPASUT
	mcIISUTt = CreateMatrixCurrency(trktrans, "II_SUT", null, null, null)	
	mcIISUT := (mcIISUT + mcIISUTt)/2

	//MUT 
	mcIIMUT = CreateMatrixCurrency(trkOD, "II_MUT", "Internal", "Internal", )
	mcPAMUT = CreateMatrixCurrency(trkPA, "II_MUT", null, null, null)
	mcIIMUT := mcPAMUT
	mcIIMUTt = CreateMatrixCurrency(trktrans, "II_MUT", null, null, null)	
	mcIIMUT := (mcIIMUT + mcIIMUTt)/2
	
	//TODO: use old process in highway assignment to convert PA2OD for trucks 
	// Apply time-of-day factors
	//cnames = {"AM_SUT", "PM_SUT", "OP_SUT", "AM_MUT", "PM_MUT", "OP_MUT"}
	
    //time of day factoring                                                           
	trks = CreateMatrixCurrencies(trkOD,"internal","internal",null)
	
	//0.5276 is OP factor (MD+OP) - 0.419 is MD factor within the OP periods
	trks.AM_SUT :=	mcIISUT*0.1980
	trks.MD_SUT :=	mcIISUT*0.5276*0.419
	trks.PM_SUT :=	mcIISUT*0.2744
	trks.OP_SUT :=	mcIISUT*0.5276*(1-0.419)
	 
	trks.AM_MUT :=	mcIIMUT*0.1980
	trks.MD_MUT :=	mcIISUT*0.5276*0.419
	trks.PM_MUT :=	mcIIMUT*0.2744
	trks.OP_MUT :=  mcIIMUT*0.5276*(1-0.419)
	
	ok=1
	
	quit:
	Return(ok)
		
endMacro

Macro "CloseAllViews"

	on error, notfound do
		goto quit
	end

	list_open_views = GetViewNames()

	for vw = 1 to list_open_views.length do
		vw_name = list_open_views[vw]
		CloseView(vw_name)
	end
	
	ok=1
	
	quit:
	Return(ok)

endMacro

Macro "Create a new matrix" (tazname, outMatFile, matrix_cores)

	mat = CreateMatrix({tazname +"|", tazname  + ".Zone_id", "Rows"},{tazname +"|", tazname  + ".Zone_id", "Cols"},
             {{"File Name", outMatFile},{"Type","Float"},
             {"Tables", matrix_cores}})
    
endMacro

Macro "4TCV_Model"
	shared path, skim_truck, skim_truck_time, tazvec, tazindex_file
	shared od_cv, cv_gen_outfile, cv_gravity_outfile, cv_balance_outfile
	shared ID, BAS, IND, RET, SRVC, HH
	
	on error, notfound do
		goto quit
	end

	GenAccess 		=   GetDataVector(tazvec+"|", "GenAccess", )
									
	//Generation
	//CV_ADJFACTOR = 0.10  //from Chattanooga - how is it calculated? for Nashville, when compared with old CV demand, factor=0.70
	CV_ADJFACTOR = 0.70
	CV_Gen = 1.110*BAS + 0.938*IND + 0.888*RET + 0.437*SRVC + 0.251*HH 

	CV_O = nz(CV_Gen) * CV_ADJFACTOR
	CV_D = nz(CV_Gen) * CV_ADJFACTOR

	//Distribution
	cvpavw = CreateTable("cvpa", cv_gen_outfile, "FFB", {
						{"ID", "Integer", 10, null, "No"},
						{"CV_Gen", "Integer", 10, null, "No"},
						{"CV_II_O", "Real", 10, 2, "No"}, 
						{"CV_II_D", "Real", 10, 2, "No"}, 
						{"CV_YY_O", "Real", 10, 2, "No"}, 
						{"CV_YY_D", "Real", 10, 2, "No"}
						})

	linecount = VectorStatistic(ID, "Count", )
	r = AddRecords(cvpavw, null, null, {{"Empty Records", linecount}})

	SetDataVectors(cvpavw + "|", {{"ID", ID}, 
									{"CV_Gen",CV_Gen},
									{"CV_II_O",CV_O}, 
									{"CV_II_D",CV_D},
									{"CV_YY_O",CV_O}, 
									{"CV_YY_D",CV_D}
								}, {{"Sort Order",{{"ID","Ascending"}}}}) 

	// ----- BALANCING ------
	//RunMacro("TCB Init")
	Opts = null
	Opts.Input.[Data View Set] = {cv_gen_outfile, cvpavw}
	Opts.Field.[Vector 1] = {cvpavw+".CV_II_O"} 
	Opts.Field.[Vector 2] = {cvpavw+".CV_II_D"}
	Opts.Global.[Store Type] = "Real"
    Opts.Global.[Output Type] = "WRITE"
    Opts.Output.[Output Table] = cv_balance_outfile
		
	RunMacro("TCB Run Procedure", 1, "Balance", Opts)
	 
	// ----- CV TRIP DISTRIBUTION ------
    // Create K factor matrices for OD portion of utilities (except straight impedance)
	kmat = OpenMatrix(skim_truck, )
	 
	//River Crossing
	mcriv = RunMacro("CheckMatrixCore", kmat, "RiverX (Skim)", "TAZ_ID", "TAZ_ID",)
	
	//Intrazonal 1s
	mciz  = RunMacro("CheckMatrixCore", kmat, "IZ", "TAZ_ID", "TAZ_ID",)
	mciz := 0     
	v1 = Vector(mciz.cols, "float", {{"Constant", 1}})
	SetMatrixVector(mciz, v1, {{"Diagonal"}})
	
    // TAZ portion of utilities
	mckCV = RunMacro("CheckMatrixCore", kmat, "kCV", "TAZ_ID", "TAZ_ID",)
    k_CV = exp(-0.4923*GenAccess)

    // Exponentiated utilities (less any straight impedance component) by adding OD elements to TAZ component  
    mckCV := k_CV * exp(-0.8625*mcriv + -1.4781*mciz)
	
	//Run Gravity Model to get PAs
	//RunMacro("TCB Init")
	Opts = null
	Opts.Input.[PA View Set] = {cv_gen_outfile, cvpavw}
	Opts.Input.[FF Matrix Currencies] = {null}
	Opts.Input.[Imp Matrix Currencies] = {{skim_truck, skim_truck_time, "TAZ_ID", "TAZ_ID"}} 
    Opts.Input.[KF Matrix Currencies] = {{skim_truck, "kCV", "TAZ_ID", "TAZ_ID"}} 
	Opts.Field.[Prod Fields]      = {cvpavw+".CV_II_O"}
	Opts.Field.[Attr Fields]      = {cvpavw+".CV_II_D"}
	Opts.Global.[Purpose Names]   = {"CV_II"     }
	Opts.Global.Iterations        = {500          }
	Opts.Global.Convergence       = {0.001        }
	Opts.Global.[Constraint Type] = {"Double"     }
	Opts.Global.[Fric Factor Type]= {"Exponential"}
	Opts.Global.[A List]          = {1            }
	Opts.Global.[B List]          = {0.3          }    
	Opts.Global.[C List]          = {0.0071       }
	Opts.Flag.[Use K Factors]     = {1            }
	Opts.Flag.[Post Process] = "False"
	Opts.Output.[Output Matrix].Label = "CV Trip Matrix"
	Opts.Output.[Output Matrix].Type = "Float"
	Opts.Output.[Output Matrix].[File based] = "FALSE"
	Opts.Output.[Output Matrix].Sparse = "False"
	Opts.Output.[Output Matrix].[Column Major] = "False"
	Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = cv_gravity_outfile

    ok = RunMacro("TCB Run Procedure", "Gravity", Opts, &Ret)
    if !ok then Return(RunMacro("TCB Closing", ok, True))
	CloseView(cvpavw)
	
	//PA to OD by Averaging with Transpose
	cvPA = OpenMatrix(cv_gravity_outfile,)
	tempmtx = GetTempFileName(".mtx")
	cvtrans = TransposeMatrix(cvPA, {{"File Name", tempmtx}, {"Label", "Transpose"}, {"Type", "Double"}, {"Sparse", "No"}, {"Column Major", "No"}, {"File Based", "Yes"}, {"Compression", 1}}) 

	cnames = {"CV_II", "AM_CV", "MD_CV", "PM_CV", "OP_CV"}
	tazindex_vw = OpenTable("tazindex_vw", "CSV", {tazindex_file},)
	RunMacro("Create a new matrix", tazindex_vw, od_cv, cnames)
	
	//create a new index
	SetView(tazindex_vw)
	nsel = SelectByQuery("Internal", "Several", "Select * where Dest_eligible=1",)
	cvOD = OpenMatrix(od_cv,)
	new_index = CreateMatrixIndex("Internal", cvOD, "Both", tazindex_vw + "|Internal", "Zone_id", "Zone_id")
	CloseView(tazindex_vw)
	
	mcCV  = CreateMatrixCurrency(cvOD   , "CV_II", "internal", "Internal", null)
	mcPACV = CreateMatrixCurrency(cvPA, "CV_II", null, null, null)
	mcCV := mcPACV
	
	mcCVt = CreateMatrixCurrency(cvtrans, "CV_II", null, null, null)
	mcCV := (mcCV + mcCVt)/2
	
	//time of day factoring									
	cv = CreateMatrixCurrencies(cvOD,"internal","internal",null)
	cv.AM_CV :=	mcCV*0.1980
	cv.MD_CV :=	mcCV*0.5276*0.419
	cv.PM_CV :=	mcCV*0.2744
	cv.OP_CV :=	mcCV*0.5276*(1-0.419)
	
	ok=1
	
	quit:
	Return(ok)
		
endMacro

Macro "CheckMatrixCore" (mtx, thiscore, rowindex, colindex)
     coreexists = 0
     corenames = GetMatrixCoreNames(mtx)
     for i = 1 to corenames.length do
          if lower(corenames[i]) = lower(thiscore) then do 
		  coreexists = 1
		  goto jump
		  end
     end
	 
     if coreexists <> 1 then AddMatrixCore(mtx, thiscore)
	 
	 jump:
	 mc = CreateMatrixCurrency(mtx, thiscore, rowindex, colindex, null)
	 Return(mc)
endMacro

//Dataview Tools
Macro "addfields" (dataview, newfldnames, typeflags)
	//Add a new field to a dataview; does not overwrite
	//RunMacro("addfields", mvw.node, {"Delay", "Centroid", "Notes"}, {"r","i","c"})
	fd = newfldnames.length
	dim fldtypes[fd]
	
	if TypeOf(typeflags) = "array" then do 
		for i = 1 to newfldnames.length do
			if typeflags[i] = "r" then fldtypes[i] = {"Real", 12, 2}
			if typeflags[i] = "i" then fldtypes[i] = {"Integer", 10, 3}
			if typeflags[i] = "c" then fldtypes[i] = {"String", 16, null}
		end
	end
	
	if TypeOf(typeflags) = "string" then do 
		for i = 1 to newfldnames.length do
			if typeflags = "r" then fldtypes[i] = {"Real", 12, 2}
			if typeflags = "i" then fldtypes[i] = {"Integer", 10, 3}
			if typeflags = "c" then fldtypes[i] = {"String", 16, null}
		end
	end

	SetView(dataview)
   struct = GetTableStructure(dataview)

	dim snames[1]
   for i = 1 to struct.length do
      struct[i] = struct[i] + {struct[i][1]}
	snames = snames + {struct[i][1]}
   end

	modtab = 0
   for i = 1 to newfldnames.length do
      pos = ArrayPosition(snames, {newfldnames[i]}, )
      if pos = 0 then do
         newstr = newstr + {{newfldnames[i], fldtypes[i][1], fldtypes[i][2], fldtypes[i][3], 
					"false", null, null, null, null}}
         modtab = 1
      end
   end

   if modtab = 1 then do
      newstr = struct + newstr
      ModifyTable(dataview, newstr)
   end
endMacro

Macro "dropfields" (dataview, fldnames)
	//Remove field in a dataview
	//RunMacro("dropfields", mvw.node, {"Delay","Centroid","Notes"})

   struct = GetTableStructure(dataview)

   for i = 1 to struct.length do
      struct[i] = struct[i] + {struct[i][1]}
      pos = ArrayPosition(fldnames, {struct[i][1]}, )
      if pos = 0 then do
          newstr = newstr + {struct[i]}
      end
      else modtab = 1
   end

   if modtab = 1 then do
      ModifyTable(dataview, newstr)
   end
endMacro

Macro "Run_Summaries"
	shared skim_truck, od_trk, od_cv
	
	//trucks - Avg. TL
	ok = RunMacro("GenerateTripLengths", od_trk, {"II_SUT", "II_MUT"}, {skim_truck, "Length"}, {"Origin","Destination"}, {"Rows", "Cols"})
	if (ok<>1) then goto quit
	
	//SU - TLFD
	ok = RunMacro("TLFD", od_trk, "II_SUT", {skim_truck, "Length"}, {"Origin","Destination"}, {"Rows", "Cols"})
	if (ok<>1) then goto quit

	//MU - TLFD
	ok = RunMacro("TLFD", od_trk, "II_MUT", {skim_truck, "Length"}, {"Origin","Destination"}, {"Rows", "Cols"})
	if (ok<>1) then goto quit

	//CV - Avg. TL
	ok = RunMacro("GenerateTripLengths", od_cv, {"CV_II"}, {skim_truck, "Length"}, {"Origin","Destination"}, {"Rows", "Cols"})
	if (ok<>1) then goto quit
	
	//CV - TLFD
	ok = RunMacro("TLFD", od_cv, "CV_II", {skim_truck, "Length"}, {"Origin","Destination"}, {"Rows", "Cols"})
	if (ok<>1) then goto quit

	quit:
	Return(ok)

endMacro

Macro "TLFD" (trips_mat, core_name, skim_mat, skim_index, trip_index, region)
	shared Scen_Dir
	
	on error, notfound do
		goto quit
	end
	
	
	in_dir = Scen_Dir + "outputs\\"
	out_dir = in_dir
	
	filename = SplitPath(trips_mat)
	inMat = filename[3] + ".mtx"	
	outMat = filename[3] + "_TLFD_" + core_name + ".mtx"
	
	skim_file = skim_mat[1]
	skim_name = skim_mat[2]

	Opts = null

    Opts.Input.[Base Currency] = {in_dir + inMat, core_name, trip_index[1], trip_index[2]}
    Opts.Input.[Impedance Currency] = {skim_file, skim_name, skim_index[1], skim_index[2]}
    Opts.Global.[Start Option] = 2
    Opts.Global.[Start Value] = 0
    Opts.Global.[End Option] = 2
    Opts.Global.[End Value] = 25
    Opts.Global.Method = 1
    Opts.Global.[Number of Bins] = 10
    Opts.Global.Size = 1
    Opts.Global.[Statistics Option] = 1
    Opts.Global.[Min Value] = 0
    Opts.Global.[Max Value] = 0
	Opts.Global.[Create Chart] = 0
    Opts.Output.[Output Matrix].Label = "Output Matrix"
    Opts.Output.[Output Matrix].[File Name] = out_dir + outMat
    ret_value = RunMacro("TCB Run Procedure", "TLD", Opts) 
	
	Return(ret_value)	
	
	quit:
	Return(ret_value)

endMacro

Macro "GenerateTripLengths" (trips_mat, core_names, skim_mat, skim_index, trip_index)
	shared Scen_Dir
	
	on error, notfound do
		goto quit
	end	
	
	in_dir = Scen_Dir + "outputs\\"
	out_dir = in_dir
	
	filename = SplitPath(trips_mat)
	inMat = filename[3] + ".mtx"	
	outMat = filename[3] + "_TL" + ".mtx"
	
	CopyFile(in_dir + inMat, out_dir + outMat)
	
	skim_file = skim_mat[1]
	skim_name = skim_mat[2]
	matSkim = OpenMatrix(skim_file,)
	mcSkim = CreateMatrixCurrency(matSkim, skim_name, skim_index[1], skim_index[2], )

	for core=1 to core_names.length do
		matOut = OpenMatrix(out_dir+outMat,) 
		mcOut = CreateMatrixCurrency(matOut, core_names[core], trip_index[1], trip_index[2], )		
		mcOut := nz(mcOut) * nz(mcSkim)
	
	end
	
	sumStats_trips = RunMacro("GetMatrixSum", in_dir, inMat, core_names)
	sumStats_vmt = RunMacro("GetMatrixSum", out_dir, outMat, core_names)
	
	file_writer = RunMacro("Start a File Writer", out_dir + filename[3] + "_TL_" + region + ".csv")
	WriteLine(file_writer, "core_name,trips,vmt,trip_length")
	for core=1 to core_names.length do
		trip_type = sumStats_trips[core][1]
		trips = sumStats_trips[core][2]
		vmt = sumStats_vmt[core][2]
		trip_length = StringToReal(vmt)/StringToReal(trips)
		
		out_string = trip_type + "," + trips + "," + vmt + "," + RealToString(trip_length)
		WriteLine(file_writer, out_string)
	end
	
	CloseFile(file_writer)
	//DeleteFile(out_dir+outMat)
	
	ok=1
	
	quit:
	Return(ok)	
	
endMacro

Macro "Start a File Writer" (outfile)
	shared stats_header
	
	if GetFileInfo(outfile) <> null then do
		DeleteFile(outfile)
	end
	
	fptr = OpenFile(outfile, "a")
	
	Return(fptr)

endMacro

Macro "GetMatrixSum" (dir, mat_file, core_names)
			
	dim outStats[core_names.length]
	mat = OpenMatrix(dir + mat_file,)
	stat_array = MatrixStatistics(mat,)
	count=1
	for core=1 to stat_array.length do
		stats = stat_array[core]
		if (ArrayPosition(core_names,{stats[1]},)>0) then do
			out_string = mat_file + "," + stats[1]
			for stat = 1 to stats[2].length do
				summary = stats[2][stat]
				out_string = out_string + "," + RealToString(summary[2])		
			end
			sum = stats[2][2]
			outStats[count] = {stats[1], RealToString(sum[2])}
			count = count + 1
		end
	end
	
	Return(outStats)
	
endMacro

