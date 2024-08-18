//**************************************
//*					Highway Skimming					 *
//**************************************
/*
3 skims:
Terminal
Travel Cost
Truck Travel Cost
Skim_0: read field names and add layers to the map
Skim_1: Build Highway Network
Skim_2: Shortest path using Length for EE trips
Skim_3: Terminal Time
Skim_4: Intrazonal Travel Time
*/
Macro "Highway Skimming" (Args)    // Highway Skimming
	shared  Scen_Dir, loop
   
	starttime = RunMacro("RuntimeLog", {"Highway Skimming - Feedback Loop " + i2s(loop), null})
   	RunMacro("HwycadLog", {"2.1 HwySkimming.rsc", "  ****** Highway Skimming ****** "})

    feedback_iteration = loop
   
    // skim_0:
	RunMacro ("TCB Init")
   
    // Input highway and TAZ files. 
    hwy_db = Args.[hwy db]
	taz_db = Args.[taz]
	layers = GetDBlayers(hwy_db)
    llayer = layers[2]
    nlayer = layers[1]
   
    db_linklyr = hwy_db + "|" + llayer
    db_nodelyr = hwy_db + "|" + nlayer
     
    network_file = Args.[Network File]
	
    dim hov_skims_fileName[4], hov_skims[4]  
    hov_skims_fileName[1] = Left(Args.[am skim],Len(Args.[am skim])-8) + "_hov.mtx"
    hov_skims_fileName[2] = Left(Args.[pm skim],Len(Args.[pm skim])-8) + "_hov.mtx"
    hov_skims_fileName[3] = Left(Args.[op skim],Len(Args.[op skim])-8) + "_hov.mtx"  
    hov_skims_fileName[4] = Left(Args.[md skim],Len(Args.[md skim])-8) + "_hov.mtx"
      
    hov_skims[1]={hov_skims_fileName[1],"[time_AM_AB_time_AM_BA]","AM"}  
    hov_skims[2]={hov_skims_fileName[2],"[time_PM_AB_time_PM_BA]","PM"}
    hov_skims[3]={hov_skims_fileName[3],"[time_OP_AB_time_OP_BA]","OP"}
    hov_skims[4]={hov_skims_fileName[4],"[time_MD_AB_time_MD_BA]","MD"}    
    
	dim sov_skims[5] //File name, field
	sov_skims[1]={Args.[am skim],"[time_AM_AB_time_AM_BA]","AM"}
	sov_skims[2]={Args.[pm skim],"[time_PM_AB_time_PM_BA]","PM"}
	sov_skims[3]={Args.[op skim],"[time_OP_AB_time_OP_BA]","OP"}
	sov_skims[4]={Args.[md skim],"[time_MD_AB_time_MD_BA]","MD"}
	sov_skims[5]={Args.[ff skim],"[time_FF_AB_time_FF_BA]","FF"}
    
    //**************************************
	//*      Skim_1: Build Highway Network - build it only once          *
	//**************************************   
	// skim_1:
	RunMacro("HwycadLog", {"Build highway network", null})
    RunMacro("Build Hwy Network", Args)

    //Add TAZ layer
    layers = GetDBlayers(taz_db)
    tazname = layers[1]
	temp_layer =AddLayer("temp",tazname,taz_db,tazname)
	SetView(tazname)
	
    //**************************************
	//*      Skim_2: Shortest path using Length     *
	//**************************************   
	// skim_2:
	RunMacro("HwycadLog", {"Shortest path using length", null})
   Opts = null
   Opts.Input.Network = network_file
   Opts.Input.[Origin Set] = {db_nodelyr, nlayer, "Selection", "Select * where CCSTYLE=97 or CCSTYLE=98 or CCSTYLE=99"}
   Opts.Input.[Destination Set] = {db_nodelyr, nlayer, "Selection"}
   Opts.Input.[Via Set] = {db_nodelyr, nlayer}
   Opts.Field.Minimize = "Length"
   Opts.Field.Nodes = nlayer + ".ID"
   Opts.Output.[Output Matrix].Label = "EE"
   Opts.Output.[Output Matrix].[File Name] = Scen_Dir + "outputs\\ExtDistSkims.mtx"
   ret_value = RunMacro("TCB Run Procedure", 1, "TCSPMAT", Opts)
   if !ret_value then goto quit 

    //**************************************
	//*      Skim_4: Terminal Time			               
	//**************************************  
	RunMacro("HwycadLog", {"Terminal time", null}) 	
	CreateMatrix({tazname +"|", tazname  + ".ID","TAZ_ID"},{tazname +"|", tazname  + ".ID","TAZ_ID"},
             {{"File Name",Scen_Dir + "//outputs//terminal_time.mtx"},{"Type","Float"},
             {"Tables",{"origin_time","destination_time","total_time"}}})

    dim terminal[4]
    terminal[1]={"CBD",2.5}
    terminal[2]={"URBAN",1.5}
    terminal[3]={"SU",1}
    terminal[4]={"RURAL",0.5}

	for i=1 to terminal.length do 
		//Matrix Index - Create Area Type Matrix Index
		Opts = null
		Opts.Input.[Current Matrix] = Scen_Dir + "//outputs//terminal_time.mtx"
		Opts.Input.[Index Type] = "Both"
		Opts.Input.[View Set] = {taz_db+"|"+tazname, tazname, "Selection", "Select * where Predict='"+terminal[i][1]+"'"}
		Opts.Input.[Old ID Field] = {taz_db+"|"+tazname, "ID"}
		Opts.Input.[New ID Field] = {taz_db+"|"+tazname, "ID"}
		Opts.Output.[New Index] = terminal[i][1]
		ret_value = RunMacro("TCB Run Operation", "Add Matrix Index", Opts, &Ret)
		if !ret_value then goto quit
		
		// Terminal Time - Adding Orgin Terminal Time
		Opts = null
		Opts.Input.[Matrix Currency] = {Scen_Dir + "//outputs//terminal_time.mtx", "origin_time", terminal[i][1], "TAZ_ID"}
		Opts.Global.Method = 1
		Opts.Global.Value = terminal[i][2]
		Opts.Global.[Cell Range] = 2
		Opts.Global.[Matrix Range] = 1
		Opts.Global.[Matrix List] = {"origin_time", "destination_time", "total_time"}
		ret_value = RunMacro("TCB Run Operation", 7, "Fill Matrices", Opts)
		if !ret_value then goto quit
	   
		// Terminal Time - Adding Destination Terminal Time
		Opts = null
		Opts.Input.[Matrix Currency] = {Scen_Dir + "//outputs//terminal_time.mtx", "destination_time", "TAZ_ID", terminal[i][1]}
		Opts.Global.Method = 1
		Opts.Global.Value = terminal[i][2]
		Opts.Global.[Cell Range] = 2
		Opts.Global.[Matrix Range] = 1
		Opts.Global.[Matrix List] = {"origin_time", "destination_time", "total_time"}
		ret_value = RunMacro("TCB Run Operation", 7, "Fill Matrices", Opts)
		if !ret_value then goto quit
	end 
	
	// Fill Matrices - Sum the total terminal time
	Opts = null
	Opts.Input.[Matrix Currency] = {Scen_Dir + "//outputs//terminal_time.mtx", "total_time", "TAZ_ID", "TAZ_ID"}
	Opts.Global.Method = 11
	Opts.Global.[Cell Range] = 2
	Opts.Global.[Expression Text] = "nz([origin_time])+ nz([destination_time])"
	Opts.Global.[Force Missing] = "Yes"
	ret_value = RunMacro("TCB Run Operation", 11, "Fill Matrices", Opts)
	if !ret_value then goto quit   
   
    //**************************************
	//*      Create TOD Skim Matrices & Add Intrazonal and Terminal 
	//************************************** 
	RunMacro("HwycadLog", {"Build HOV skims", null})	
    // Build HOV skims
    for i=1 to hov_skims.length do

        // for feedback
        if feedback_iteration = 1 then
            skim_field = hov_skims[i][2]
        else do
            if i <=4 then
                skim_field = "_MSATime" + hov_skims[i][3]
            else // nothing for FF
                skim_field = hov_skims[i][2]
        end
    
        RunMacro("Build Hwy Skims", network_file, db_nodelyr, nlayer, hov_skims[i],skim_field)
        RunMacro("Add Intrazonal & Terminal Times",  hov_skims[i],skim_field)
    end

	RunMacro("HwycadLog", {"Build SOV skims", null})
    // Build SOV skims
    for i=1 to sov_skims.length do  
        // Disable HOV links
        net = ReadNetwork(network_file)
        NetOpts = null
        NetOpts.[Link ID] = link_lyr+".ID"
        NetOpts.[Type] = "Enable"
        NetOpts.[Write to file] = "Yes"
        ChangeLinkStatus(net,, NetOpts) // first enable all links
        NetOpts.[Type] = "Disable"
        NetworkEnableDisableLinkByExpression(net, "hov = 1", NetOpts)

        // for feedback
        if feedback_iteration = 1 then
            skim_field = sov_skims[i][2]
        else do
            if i <=4 then
                skim_field = "_MSATime" + sov_skims[i][3]
            else
                skim_field = sov_skims[i][2]
        end
      
        RunMacro("Build Hwy Skims", network_file, db_nodelyr, nlayer, sov_skims[i],skim_field)
        RunMacro("Add Intrazonal & Terminal Times",  sov_skims[i],skim_field)
      
        NetOpts.[Type] = "Enable"                                   
        NetworkEnableDisableLinkByExpression(net, "hov = 1", NetOpts)

    end 

    if (loop > 1) then do
        //Add a new core "[time_am_AB / time_am_BA]" to highway skims - mode choice model needs this core
        // only to first 4 cores
        RunMacro("AddCore", sov_skims, 4)
        RunMacro("AddCore", hov_skims, 4)
    end
    
 	RunMacro("HwycadLog", {"Save and copy skims", null})
    //Save and copy skims
    RunMacro("SaveAndCopySkims", sov_skims)
    RunMacro("SaveAndCopySkims", hov_skims)

	RunMacro("HwycadLog", {"2.1 HwySkimming.rsc", "Finished Highway Skimming"})
	endtime = RunMacro("RuntimeLog", {"Highway Skimming - Feedback Loop " + i2s(loop), starttime})	
    
    ret_value = 1
    quit:
    CloseMap("temp")
    return(ret_value)
endMacro    
 
Macro "Build Hwy Network" (Args)
    shared  Scen_Dir, loop

    // Input highway and TAZ files. 
    hwy_db = Args.[hwy db]
	layers = GetDBlayers(hwy_db)
    llayer = layers[2]
    nlayer = layers[1]
   
    db_linklyr = hwy_db + "|" + llayer
    db_nodelyr = hwy_db + "|" + nlayer
    
    temp_map = CreateMap("temp",{{"scope",Scope(Coord(-80000000, 44500000), 200.0, 100.0, 0)}})
    temp_layer = AddLayer(temp_map,llayer,hwy_db,llayer)
    temp_layer = AddLayer(temp_map,nlayer,hwy_db,nlayer)
    
    network_file = Args.[Network File]    
    
    if loop = 1 then do
        Opts = null
        Opts.Input.[Link Set] = {db_linklyr , llayer, "Selection", "Select * where Lanes>0 and Assignment_LOC=1"}
        Opts.Global.[Network Label] = "Based on "+db_linklyr
        //Opts.Global.[Network Options].[Node Id] = nlayer+".ID"
        Opts.Global.[Network Options].[Turn Penalties] = "Yes"
        Opts.Global.[Network Options].[Keep Duplicate Links] = "FALSE"
        Opts.Global.[Network Options].[Ignore Link Direction] = "FALSE"
        Opts.Global.[Network Options].[Time Units] = "Minutes"
        Opts.Global.[Link Options] = {{"Length", {llayer+".Length", llayer+".Length", , , "False"}}, 
        {"WalkTime", {llayer+".WalkTime", llayer+".WalkTime", , , "False"}}, 
        {"[capacity_am_AB_capacity_am_BA]", {llayer+".capacity_am_AB", llayer+".capacity_am_BA", , , "False"}}, 
        {"[capacity_pm_AB_capacity_pm_BA]", {llayer+".capacity_pm_AB", llayer+".capacity_pm_BA", , , "False"}}, 
        {"[capacity_op_AB_capacity_op_BA]", {llayer+".capacity_op_AB", llayer+".capacity_op_BA", , , "False"}}, 
        {"[capacity_md_AB_capacity_md_BA]", {llayer+".capacity_md_AB", llayer+".capacity_md_BA", , , "False"}}, 
        {"[capacity_daily_AB_capacity_daily_BA]", {llayer+".capacity_daily_AB", llayer+".capacity_daily_BA", , , "False"}}, 
        {"[SPD_FF_AB_SPD_FF_BA]", {llayer+".SPD_FF_AB", llayer+".SPD_FF_BA", , , "False"}}, 
        {"[SPD_AM_AB_SPD_AM_BA]", {llayer+".SPD_AM_AB", llayer+".SPD_AM_BA", , , "False"}}, 
        {"[SPD_MD_AB_SPD_MD_BA]", {llayer+".SPD_MD_AB", llayer+".SPD_MD_BA", , , "False"}}, 
        {"[SPD_PM_AB_SPD_PM_BA]", {llayer+".SPD_PM_AB", llayer+".SPD_PM_BA", , , "False"}}, 
        {"[SPD_OP_AB_SPD_OP_BA]", {llayer+".SPD_OP_AB", llayer+".SPD_OP_BA", , , "False"}}, 
        {"[time_FF_AB_time_FF_BA]", {llayer+".time_FF_AB", llayer+".time_FF_BA", , , "False"}}, 
        {"[time_AM_AB_time_AM_BA]", {llayer+".time_AM_AB", llayer+".time_AM_BA", , , "False"}}, 
        {"[time_MD_AB_time_MD_BA]", {llayer+".time_MD_AB", llayer+".time_MD_BA", , , "False"}}, 
        {"[time_PM_AB_time_PM_BA]", {llayer+".time_PM_AB", llayer+".time_PM_BA", , , "False"}}, 
        {"[time_OP_AB_time_OP_BA]", {llayer+".time_OP_AB", llayer+".time_OP_BA", , , "False"}}, 
        {"hov", {llayer+".hov", llayer+".hov", , , "False"}}, 
        {"alpha", {llayer+".alpha", llayer+".alpha", , , "False"}}, 
        {"beta", {llayer+".beta", llayer+".beta", , , "False"}},
        {"TRUCKNET", {llayer+".TRUCKNET", llayer+".TRUCKNET", , , "False"}},
        {"TRUCKCOST", {llayer+".TRUCKCOST", llayer+".TRUCKCOST", , , "False"}},
		{"RiverX", {llayer+".RiverX", llayer+".RiverX", , , "False"}}}
        Opts.Global.[Length Units] = "Miles"
        Opts.Global.[Time Units] = "Minutes"
        Opts.Output.[Network File] = network_file
        ret_value = RunMacro("TCB Run Operation", "Build Highway Network", Opts, &Ret)
        if !ret_value then goto quit 
	
        // centroids
        Opts = null
        Opts.Input.Database = hwy_db
        Opts.Input.Network = network_file
        Opts.Input.[Centroids Set] = {hwy_db+"|"+nlayer, nlayer, "selection", "Select * where ccstyle=97 or ccstyle=98 or ccstyle=99"}
        Opts.Input.[Toll Set] = {db_linklyr , llayer}
        ret_value = RunMacro("TCB Run Operation", "Highway Network Setting", Opts, &Ret)
        if !ret_value then goto quit 
    
    end
    quit:
    return(ret_value)
endMacro

 
//**************************************
//*    Create TOD Skim Matrices     
//**************************************     
Macro "Build Hwy Skims"(network_file, db_nodelyr, nlayer, skim, SkimField)    

    Opts = null
    Opts.Input.Network = network_file
    Opts.Input.[Origin Set] = {db_nodelyr, nlayer, "Selection", "Select * where CCSTYLE=97 or CCSTYLE=98 or CCSTYLE=99"}
    Opts.Input.[Destination Set] = {db_nodelyr, nlayer, "Selection"}
    Opts.Input.[Via Set] = {db_nodelyr, nlayer}
    Opts.Field.Minimize = SkimField
	Opts.Field.[Skim Fields] = {{"RiverX","All"}}  //added for internal truck model
    Opts.Field.Nodes = nlayer + ".ID"
    Opts.Output.[Output Matrix].Label = "Shortest Path"
    Opts.Output.[Output Matrix].[File Name] = skim[1]
    ret_value = RunMacro("TCB Run Procedure","TCSPMAT", Opts, &Ret)
    if !ret_value then goto quit

    // Add Matrix Core "Shortest Path - "+SkimField. After adding new skim "RiverX", output matrix core name was different. 
	// So, this step was added to add a consistent core name and avoid breaking the model code.
    Opts = null
    Opts.Input.[Input Matrix] = skim[1]
    Opts.Input.[New Core] = "Shortest Path - " + SkimField
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Core", Opts, &Ret)
    if !ret_value then goto quit
	
	// set the new matrix core to skimmed field
	m = OpenMatrix(skim[1],)
	mc1 = CreateMatrixCurrency(m, SkimField,,, )
	mc2 = CreateMatrixCurrency(m, "Shortest Path - "+SkimField,,, )
    mc2 := mc1

    //add taz index
    Opts = null
    Opts.Input.[Current Matrix] = skim[1]
    Opts.Input.[Index Type] = "Both"
    Opts.Input.[View Set] = {db_nodelyr, nlayer, "Selection", "Select * where CCSTYLE=99"}
    Opts.Input.[Old ID Field] = {db_nodelyr, "ID"}
    Opts.Input.[New ID Field] = {db_nodelyr, "ID"}
    Opts.Output.[New Index] = "TAZ_ID"
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Index", Opts, &Ret)
    if !ret_value then goto quit

    //add external station index
    Opts = null
    Opts.Input.[Current Matrix] = skim[1]
    Opts.Input.[Index Type] = "Both"
    Opts.Input.[View Set] = {db_nodelyr, nlayer, "Selection", "Select * where CCSTYLE=97 or CCSTYLE=98"}
    Opts.Input.[Old ID Field] = {db_nodelyr, "ID"}
    Opts.Input.[New ID Field] = {db_nodelyr, "ID"}
    Opts.Output.[New Index] = "ee"
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Index", Opts, &Ret)
    if !ret_value then goto quit
    
    // calculate the intrazonal travel time for tazs
    Opts = null
    Opts.Input.[Matrix Currency] = {skim[1], "Shortest Path - "+SkimField, "TAZ_ID", "TAZ_ID"}
    Opts.Global.Factor = 0.5
    Opts.Global.Neighbors = 3
    Opts.Global.Operation = 1
    Opts.Global.[Treat Missing] = 2
    ret_value = RunMacro("TCB Run Procedure", "Intrazonal", Opts, &Ret)
    if !ret_value then goto quit     	

    mc = RunMacro("TCB Create Matrix Currency", skim[1], "Shortest Path - "+SkimField, "ee", "ee")
    ret_value = (mc <> null)
    if !ret_value then goto quit

    FillMatrix(mc,,, {"Copy", 0}, {{"Diagonal", "Yes"}})
    quit:
    return(ret_value)
endMacro

//**************************************
//*    Add Intrazonal and Terminal   
//**************************************  
Macro "Add Intrazonal & Terminal Times"(skim, SkimField)
Shared Scen_Dir  	

    // STEP 5: Sum Peak Skim and terminal time. 
    Opts = null
    Opts.Input.[Matrix Currency] = { skim[1], "Shortest Path - "+SkimField, "TAZ_ID", "TAZ_ID"}
    Opts.Input.[Core Currencies] = {{ skim[1], "Shortest Path - "+SkimField, "TAZ_ID", "TAZ_ID"}, {Scen_Dir + "//outputs//terminal_time.mtx", "total_time", "TAZ_ID", "TAZ_ID"}}
    Opts.Global.Method = 7 
    Opts.Global.[Cell Range] = 2
    Opts.Global.[Matrix K] = {1, 1}
    Opts.Global.[Force Missing] = "No"
    ret_value = RunMacro("TCB Run Operation", "Fill Matrices", Opts)
    if !ret_value then goto quit
            
    // STEP 2: Add Matrix Core "Length"
    Opts = null
    Opts.Input.[Input Matrix] = skim[1]
    Opts.Input.[New Core] = "Length"
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Core", Opts, &Ret)
    if !ret_value then goto quit
    
    // STEP 4: Merge Matrices
    Opts = null
    Opts.Input.[Target Currency] = {skim[1], "Length", "Origin", "Destination"}
    Opts.Input.[Source Currencies] = {{Scen_Dir +  "outputs\\ExtDistSkims.mtx", "Length", "Origin", "Destination"}}
    Opts.Global.[Missing Option].[Force Missing] = "No"
    ret_value = RunMacro("TCB Run Operation", "Merge Matrices", Opts, &Ret)
    if !ret_value then goto quit
    
    // STEP 5: Intrazonal for length matrix
    Opts = null
    Opts.Input.[Matrix Currency] = {skim[1], "Length", "Origin", "Destination"}
    Opts.Global.Factor = 1
    Opts.Global.Neighbors = 3
    Opts.Global.Operation = 1
    Opts.Global.[Treat Missing] = 1
    ret_value = RunMacro("TCB Run Procedure", "Intrazonal", Opts, &Ret)
    if !ret_value then goto quit
          
    quit:
    return(ret_value)
endMacro

Macro "AddCore" (HwySkims,CoreCount)
    shared Scen_Dir, loop

    // add core to skims except ff
    for i=1 to CoreCount do
        inMat = HwySkims[i][1]
        m = OpenMatrix(inMat,)
        
        coreName = "Shortest Path - [time_" + HwySkims[i][3] + "_AB_time_" + HwySkims[i][3] + "_BA]"
        
        AddMatrixCore(m, coreName)
        
        mc1 = CreateMatrixCurrency(m, "Shortest Path - _MSATime" + HwySkims[i][3],,, )
        mc2 = CreateMatrixCurrency(m, coreName,,, )
        
        // set the new core to MSA time core
        mc2 := mc1
    end

endMacro

Macro "SaveAndCopySkims" (HwySkims)
    shared Scen_Dir, loop

    counter=HwySkims.Length
    count=1
    
    directory = Scen_Dir + "outputs\\Skims_iter" + string(loop)
    
    info = GetDirectoryInfo(directory, "Directory")
    
    if info = null then do
        CreateDirectory(directory)
    end
    
    // save by loop numbers
    for i=1 to HwySkims.Length do
        inMat = HwySkims[i][1]
        file_info = SplitPath(inMat)
        
        // save skims
        outMat = directory + "\\" + file_info[3] + "_" + string(loop) + ".mtx"
        CopyFile(inMat, outMat)  
        
    end

endMacro
