/* 
3 types of trips II, EI/IE, and EE trips

1. II non hh trips use time OP for the gravity model
2. EI/IE trips use length for the gravity model
3. EE trips use Growth Factor
*/

macro "Distribution - Non-Household" (Args)
	
	UpdateProgressBar("Internal Gravity Model - initialization", 0)
	shared prj_dry_run, Scen_Dir
    if prj_dry_run then return(1)

   hwy_db = Args.[hwy db]
	taz_db = Args.[taz]
	
	layers = GetDBlayers(hwy_db)
   llayer = layers[2]
   nlayer = layers[1]
   
   temp_map = CreateMap("temp",{{"scope",Scope(Coord(-80000000, 44500000), 200.0, 100.0, 0)}})
   temp_layer = AddLayer(temp_map,llayer,hwy_db,llayer)
   temp_layer = AddLayer(temp_map,nlayer,hwy_db,nlayer)

   	//Add TAZ layer
   	layers = GetDBlayers(taz_db)
   tazname = layers[1]
	temp_layer =AddLayer(temp_map,tazname,taz_db,tazname)
	SetView(tazname)
	
	FFtable=Args.[Friction Factors]
	FF=OpenTable("Friction Factors", "FFB", {FFtable})
	periods={"AM","MD","PM","OP"}
	
	//Balanced PA Table
	balanced_table=Args.[Non-Household PA]
	PA= OpenTable("balanced_table", "FFB", {balanced_table})
 	strct1 = GetTableStructure(PA)
 	dim trips[strct1.length]
 	
 	PA_Matrix=Args.[PA Matrix]
 	
 	//Reads the non HH trip purposes
 	for i = 2 to strct1.length do 
 		ps=ParseString(strct1[i][1], "_")
		nonhh = nonhh+{ps[1]}
		i=i+1
 	end
	
	//HH trips purposes
	purposes={"HBO","HBPD","HBSch", "HBShp", "HBW", "NHBO","NHBW"}
	modes={"DA","SR2","SR3"}
	
	for p=1 to purposes.length do
		for m=1 to modes.length do
			hh=hh+{purposes[p]+"_"+modes[m]}
		end
	end
	
	CreateMatrix(
		{PA+"|", PA+".ID1","Row"},
		{PA+"|", PA+".ID1","Columns"},
		{
		{"File Name",PA_Matrix},
		{"Type","Float"},
		{"Label","All Purpose PA"},
		{"Tables",nonhh+hh}
		})

	opskim=Args.[op skim]
	
	//current 1, op time
	currency1={Args.[op skim], "Shortest Path - [time_OP_AB / time_OP_BA]", "Origin", "Destination"}
	
	//currency 2, external length
	currency2={Scen_Dir + "\\outputs\\ExtDistSkims.mtx", "EE - Length", "Origin", "Destination"}
	
	//currency 3, internal length
	currency3={Args.[op skim], "Length", "Origin", "Destination"}
	
	//currency 4, FF skim
	currency4={Args.[ff skim], "Shortest Path - [time_FF_AB / time_FF_BA]", "Origin", "Destination"}
	
	// 1. II non hh trips use time OP for the gravity model. and EI/IE trips use length for the gravity model
	part1:
	Opts = null
	Opts.Input.[PA View Set] = {balanced_table, PA}
	Opts.Input.[FF Tables] = {{FFtable}, {FFtable}, {FFtable}, {FFtable}, {FFtable}}
	Opts.Input.[Imp Matrix Currencies] = {currency4, currency4, currency3, currency4, currency4}
	Opts.Input.[FF Matrix Currencies] = {, , , ,}
	Opts.Global.[Constraint Type] = {"Production", "Production", "Production", "Production", "Production"}
	Opts.Global.[Purpose Names] = {"IICOM", "IISU", "IIMU","IEAUTO", "IESU"}
	Opts.Global.Iterations = {100, 100, 100, 100, 100}
	Opts.Global.Convergence = {0.001, 0.001, 0.001, 0.001, 0.001}
	Opts.Global.[Fric Factor Type] = {"Gamma", "Gamma", "Table", "Gamma", "Gamma"}
	Opts.Global.[A List] = {10000, 10000,10000 ,2800 ,10000 }
	Opts.Global.[B List] = {0, 0,	0 ,0.5 ,0 }

	Opts.Global.[C List] = {0.09, 0.08, 0.07, 0.08, 0.08} 
	Opts.Field.[Prod Fields] = {"IICOM_P", "IISU_P", "IIMU_P","IEAUTO_P", "IESU_P"}
	Opts.Field.[Attr Fields] = {"IICOM_A", "IISU_A", "IIMU_A","IEAUTO_A", "IESU_A"}
	Opts.Field.[FF Table Times] = {"Friction Factors.TIME", "Friction Factors.TIME", "Friction Factors.TIME", "Friction Factors.TIME", "Friction Factors.TIME"}
	Opts.Field.[FF Table Fields] = {"IICOM", "IISU", "IIMU","IEAUTO", "IESU"}
	Opts.Output.[Output Matrix].Label = "tmp Matrix"
	Opts.Output.[Output Matrix].Compression = 1
	Opts.Output.[Output Matrix].[File Name] = Scen_Dir+"\\outputs\\tmp_dailyPA1.mtx"
	ret_value = RunMacro("TCB Run Procedure", "Gravity", Opts, &Ret)
	if !ret_value then goto quit
	
	for i=1 to Opts.Global.[Purpose Names].length do
		mc1 = RunMacro("TCB Create Matrix Currency", PA_Matrix, Opts.Global.[Purpose Names][i], ,)
	    ret_value = (mc1 <> null)
	    if !ret_value then goto quit
	    	
		mc2 = RunMacro("TCB Create Matrix Currency", Opts.Output.[Output Matrix].[File Name], Opts.Field.[FF Table Fields][i], , )
		ok = (mc2 <> null)
		if ! ret_value then goto quit
		mc1 := mc2
	end
	
	//EE trips use Growth Factor
    Opts = null
    Opts.Input.[Base Matrix Currency] = {Scen_Dir + "\\outputs\\ExtDistSkims.mtx", "EE - Length", "Origin", "Destination"}
    Opts.Input.[PA View Set] = {balanced_table, PA}
    Opts.Global.[Constraint Type] = "Doubly"
    Opts.Global.Iterations = 100
    Opts.Global.Convergence = 0.001
    Opts.Field.[Core Names Used] = {"EE - Length"}
    Opts.Field.[P Core Fields] = {PA+".EEAUTO_P"}
    Opts.Field.[A Core Fields] = {PA+".EEAUTO_A"}
    Opts.Output.[Output Matrix].Label = "tmp Matrix"
    Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = Scen_Dir+"\\outputs\\tmp_dailyPA2.mtx"
    ret_value = RunMacro("TCB Run Procedure", "Growth Factor", Opts, &Ret)
    if !ret_value then goto quit
	
	mc1 = RunMacro("TCB Create Matrix Currency", PA_Matrix, "EEAUTO", ,)
	ret_value = (mc1 <> null)
	if !ret_value then goto quit
	   	
	mc2 = RunMacro("TCB Create Matrix Currency", Opts.Output.[Output Matrix].[File Name], "EE - Length", , )
	ok = (mc2 <> null)
	if ! ret_value then goto quit
	mc1 := mc2

    Opts = null
    Opts.Input.[Base Matrix Currency] = {Scen_Dir + "\\outputs\\ExtDistSkims.mtx", "EE - Length", "Origin", "Destination"}
    Opts.Input.[PA View Set] = {balanced_table, PA}
    Opts.Global.[Constraint Type] = "Doubly"
    Opts.Global.Iterations = 100
    Opts.Global.Convergence = 0.001
    Opts.Field.[Core Names Used] = {"EE - Length"}
    Opts.Field.[P Core Fields] = {PA+".EESU_P"}
    Opts.Field.[A Core Fields] = {PA+".EESU_A"}
    Opts.Output.[Output Matrix].Label = "tmp Matrix"
    Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = Scen_Dir+"\\outputs\\tmp_dailyPA3.mtx"
    ret_value = RunMacro("TCB Run Procedure", "Growth Factor", Opts, &Ret)
    if !ret_value then goto quit
	
	mc1 = RunMacro("TCB Create Matrix Currency", PA_Matrix, "EESU", ,)
	ret_value = (mc1 <> null)
	if !ret_value then goto quit
	   	
	mc2 = RunMacro("TCB Create Matrix Currency", Opts.Output.[Output Matrix].[File Name], "EE - Length", , )
	ok = (mc2 <> null)
	if ! ret_value then goto quit
		
	mc1 := mc2
	quit:

	if !ret_value then showmessage("error in "+err)
	CloseMap(temp_map)
	return(ret_value)

endMacro
