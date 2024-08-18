/**************************************
//*  					Part 1  					   	*
//*						Initialization								 *
//**************************************
//====== 1 Initialization ======//   (Create highway network)

//**************************************
//*  				  Part 1-1  					   	*
//*						Initialization								 *
//**************************************
// Compute Link Attributes and Build Highway Network */

Macro "Initialization" (Args)// Initialization
	// shared prj_dry_run  if prj_dry_run then return(1)
	shared Scen_Dir, loop, loop_n, run_type 
	starttime = RunMacro("RuntimeLog", {"Initialization", null})	
	RunMacro("HwycadLog", {"1.1 Initialization.rsc", "Initialization"})

	// Input Files
	hwy_db = Args.[hwy db]
	//turn_penalties = Args.[turn penalties]
	// Output Files
	//hwy_network = Args.[hwy network]

	/*
	// Check on Loops in Feedback
	if (run_type =3 & loop =1)then openType = "w" 
	if (run_type =3 & loop > 1) then openType = "a"      
	test = Scen_Dir +"NumFeedbackLoops.txt"  
	fptr = OpenFile(test,openType)
	WriteLine(fptr, "Loop Number: "+String(loop) + "  Total Loops: " + String(loop_n))
	CloseFile(fptr)
	*/

	shared prj_dry_run,  Scen_Dir

	// UpdateProgressBar("Updating the network for " +Args.HYEAR + " Scenario", )
	if prj_dry_run then return(1)

	// Input highway
	hwy_db = Args.[hwy db]
	demographics = Args.[taz table]	
	taz_db = Args.[taz]

	layers = GetDBlayers(hwy_db)
	llayer = layers[2]
	db_linklyr = highway_layer + "|" + llayer

	temp_map = CreateMap("temp",{{"scope",Scope(Coord(-80000000, 44500000), 200.0, 100.0, 0)}})
	temp_layer = AddLayer(temp_map,llayer,hwy_db,llayer)
	SetView(llayer)
	RunMacro("TCB Init")

	//**************************************
	//*  CAP_FF_1 Select and fill the cap vars   *
	//**************************************
	// 1. Interstate/Freeway Capacity Equations (Functional classification = 1, 11, 12)
	// 2. Principal Arterial Capacity Equations (Functional classification = 2 or 14)
	// 3. Minor Arterial Capacity Equations (Functional classification = 6 or 16)
	// 4. Collector Road Capacity Equations (Functional classification = 7, 8, or 17)
	// 5. Ramp Capacity Equations (Functional classification = 20, 21, 22)
	// 6. Local Road Capacity Equations (Functional classification = 9, 19, 99)
	
	v_clear={"capacity",
	"capacity_daily_AB",
	"capacity_am_AB",
	"capacity_md_AB",
	"capacity_pm_AB",
	"capacity_op_AB",
	"capacity_daily_BA",
	"capacity_am_BA",
	"capacity_md_BA",
	"capacity_pm_BA",
	"capacity_op_BA",
	"SPD_FF_AB", 
	"SPD_AM_AB", 
	"SPD_MD_AB",
	"SPD_PM_AB",
	"SPD_OP_AB",

	"time_FF_AB", 
	"time_AM_AB", 
	"time_MD_AB",
	"time_PM_AB",
	"time_OP_AB",

	"SPD_FF_BA", 
	"SPD_AM_BA", 
	"SPD_MD_BA",
	"SPD_PM_BA",
	"SPD_OP_BA",

	"time_FF_BA", 
	"time_AM_BA", 
	"time_MD_BA",
	"time_PM_BA",
	"time_OP_BA",
	"Alpha",
	"Beta",
    
	"c",
	"Fw",
	"Fhv",
	"Fp",
	"Fe",
	"Fd",
	"Fsd",
	"Fsc",
	"Fctl",
	"Fpark",
	"Ft",
	"Fa",
	"capacity",
	"MOD_CLASS",
	"MOD_AREA",
    "TRUCKCOST"
	}

	dim v_null[v_clear.length]
	for i=1 to v_clear.length do
		v_null[i]="null"
	end
	
    UpdateProgressBar("Capacity and FF - clear all capacity fields", )
    
    //clear all fields
	Opts = null
	Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer}
	Opts.Global.Fields = v_clear
	Opts.Global.Method = "Formula"
	Opts.Global.Parameter = v_null
	ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit    

    // ***************** Add a Truck Toll Field - nagendra.dhakar@rsginc.com **************
	
    UpdateProgressBar("Add a truck toll field", )
    
    // STEP 1: Create TRUCKCOST field with following cost
    // STEP 2: Apply a cost of 126.1 sec/mile to all links
    // STEP 3: Removed for now
    // STEP 4: Deduct 10% of the total cost from the preferred truck links

	/* 
		//STEP 1: Create a new field    
	vw = GetView()
	strct = GetTableStructure(vw)
	for i = 1 to strct.length do
		strct[i] = strct[i] + {strct[i][1]}
	end
	strct = strct + {{"TRUCKCOST", "Real", 14, 6, "True", , , , , , , null}}

	ModifyTable(view1, strct)
	*/

   // STEP 2: Apply a cost of 126.1 sec/mile to all links
   tollfield={"TRUCKCOST"}
   tollfld_flg={"126.1*Length"}
   
   Opts = null
   Opts.Input.[View Set] = {hwy_db+"|"+llayer, llayer}
   Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer}
   Opts.Global.Fields = tollfield
   Opts.Global.Method = "Formula"
   Opts.Global.Parameter = tollfld_flg
   ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
   if !ret_value then goto quit   

	/*       
	// STEP 3: Apply additional cost to links by facility type - not for now
	dim selections_class[6]	
	selections_class[1]="select * where (Func_Class=1 or Func_Class=11 or Func_Class=20)"
	selections_class[2]="select * where (Func_Class=12)"
	selections_class[3]="select * where (Func_Class=2 or Func_Class=14 or Func_Class=6 or Func_Class=16) and SPD_LMT>=45"
	selections_class[4]="select * where (Func_Class=2 or Func_Class=14 or Func_Class=6 or Func_Class=16) and SPD_LMT<45 "
	selections_class[5]="select * where (Func_Class=7 or Func_Class=8 or Func_Class=17)"
	selections_class[6]="select * where (Func_Class=9 or Func_Class=19 or CCSTYLE=99 or Func_Class=21 or Func_Class=22 or Func_Class=97)"

	class_names={"INTERSTATE","FREEWAY","ART45","ART","COLLECTOR","LOCAL"}   
	
	tollfld_flg={{"TRUCKCOST+0*Length"},{"TRUCKCOST+0*Length"},{"TRUCKCOST+32*Length"},{"TRUCKCOST+64*Length"},{"TRUCKCOST+112*Length"},{"TRUCKCOST+160*Length"}}
	for i=1 to class_names.length do
		Opts = null
		Opts.Input.[View Set] = {hwy_db+"|"+llayer, llayer}
		Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "Selection", selections_class[i]}
		Opts.Global.Fields = tollfield
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = tollfld_flg[i]
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	end  
	*/
   
    if Args.[TruckPreferred]=1 then do   
       // STEP 4: Deduct 10% of the total cost from the preferred truck links (TRUCKNET=1)
       Opts = null
       Opts.Input.[View Set] = {hwy_db+"|"+llayer, llayer}
       Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "Selection", "Select * where TRUCKNET=1"}
       Opts.Global.Fields = tollfield
       Opts.Global.Method = "Formula"
       Opts.Global.Parameter = {"0.90*TRUCKCOST"}
       ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
       if !ret_value then goto quit
   end
   
   // ********************************************************************
   
   //non-base year senario attributes update 1-6-2014
	/*    	if Args.HYEAR<>"base" then do
		v_clear={
		"FUNC_CLASS",
		"Lanes",
		"Med",
		"CTL",
		"Assignment_LOC",
		"SPD_LMT",
		"W_Lane",
		"W_Shoulder_Out",
		"PARK",
		"Signal"
		}
	   
	   
	   dim v_fill[v_clear.length]
	   
	   for i=1 to v_clear.length do
			v_fill[i]=v_clear[i]+"_"+Args.HYEAR
	   end
	
		//update all fields
		Opts = null
		Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer}
		Opts.Global.Fields = v_clear
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = v_fill
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
		
		
		
	// 	 Default Value for the missing records
	//    1. Freeway, system to system ramps
	//    2. Principle Art
	//    3. Minor Art
	//    4. Collector
	//    5. Local
	   
	   
	   v_fclass={
	   	"1","11","12","20",
	   "2","14",
	   "6","16",
	   "7","8","17",
	   "9","19"
	   }

	   def_W_Lane={
	   	"12","12","12","12",
	   	"12","12",
	   	"11","11",
	   	"10.6","9.8","11.1",
	   	"9.8","10"	   	
	   	}
	   def_W_Shoulder_Out={
	   	"10","10","10","10",
	   	"9.1","6.6",
	   	"5.6","4",
	   	"2.6","2.1","2.7",
	   	"1.8","2"
	   	}
	   def_Signal={
	   	"1","1","1","1",
	   	"1","1",
	   	"1","1",
	   	"1","1","1",
	   	"1","1"
	   	}
	   	
	   	def_ty_terrain={
	   	"2","2","2","2",
	   	"2","2",
	   	"2","2",
	   	"2","2","2",
	   	"2","2"}
	   	
	   	v_def_fields={
		"W_Lane",
		"W_Shoulder_Out",
		"Signal",
		"TY_TERRAIN"
		}
		
	   	v_def_values={
	   		def_W_Lane,
	   		def_W_Shoulder_Out,
	   		def_Signal,
	   		def_ty_terrain
	   		}
	   	
   	
		for i=1 to v_fclass.length do
			for j=1 to v_def_fields.length do
				Opts = null
				Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer,"Selection", "Select * where FUNC_CLASS="+v_fclass[i]}
				Opts.Global.Fields = {v_def_fields[j]}
				Opts.Global.Method = "Formula"
				Opts.Global.Parameter = {"if "+ v_def_fields[j] +"=null then "+v_def_values[j][i]+ " else "+ v_def_fields[j]}
				ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
				if !ret_value then goto quit	
			end
		end
		
		
		//update lanes for the HOV lane segements
	   	Opts = null
		Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer,"Selection", "Select * where HOV_m1_"+Args.HYEAR+"<>null"}
		Opts.Global.Fields = {"lanes"}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = {"lanes-nz(HOV_m1_"+Args.HYEAR+")"}
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit		
   end  */

	endtime = RunMacro("RuntimeLog", {"Initialization", starttime})	
	ret_value = 1
	quit:
	CloseMap("temp")
	return(ret_value)
	
EndMacro

/* 
	input taz file, and the network file
	Convert TAZ to centroids
	Sum and calculate the employments, and pop density in 0.5 mile radius
	Calculate the CBD, Urban, Sub, Rural probability
	Write the result to the TAZ file
	Attach the area type to the network
*/

Macro "AREATYPE" (Args)// Initialization 1 - Area Type
  shared prj_dry_run, Scen_Dir
	
	starttime = RunMacro("RuntimeLog", {"Initialization - Area Type", null})	
	RunMacro("HwycadLog", {"1.1 Initialization.rsc", "Area Type"})
	UpdateProgressBar("Area Type - Initialization", )
	
	// Input highway and TAZ files. 
   hwy_db = Args.[hwy db]
	taz_db = Args.[taz]
	
	layers = GetDBlayers(hwy_db)
   llayer = layers[2]
   nlayer = layers[1]
   db_linklyr = hwy_db + "|" + llayer
   
   temp_map = CreateMap("temp",{{"scope",Scope(Coord(-80000000, 44500000), 200.0, 100.0, 0)}})
   temp_layer = AddLayer(temp_map,llayer,hwy_db,llayer)
	AddLayer(temp_map,nlayer,hwy_db,nlayer)
	
   	//Add TAZ layer
   	layers = GetDBlayers(taz_db)
   tazname = layers[1]
	temp_layer =AddLayer("temp",tazname,taz_db,tazname)
	SetView(tazname)
	
	//convert TAZ to centroids
	fields_array=GetFields(tazname,"All")
   field_names=fields_array[1]
   field_specs=fields_array[2]

   ExportGeography(tazname+"|",Scen_Dir+"\\outputs\\ATCentroids.dbd",   
   {{"Centroid","True"},
	{"Field Spec",field_specs},
	{"Field Name",field_names},
	{"ID Field",tazname+".ID"},
	{"Label","Centroids"},
	{"Layer Name","Centroids"}})
	
	temp_layer = AddLayer(temp_map,"Centroids",Scen_Dir+"\\outputs\\ATCentroids.dbd","Centroids")
	
	
	
	// aggregate 0.5 mile area, pop, and emp
	ColumnAggregate(tazname+"|", 0.5, "Centroids|", {{"Area05", "Sum", "Area2", },{"POP05", "Sum", "POP", },{"EMP05", "Sum", "EMP", },{"HH05", "Sum", "HH", }}, null)
	
	//calculate the density
	Opts = null
	Opts.Input.[Dataview Set] = {taz_db+"|"+tazname, tazname}
	Opts.Global.Fields = {"D_POP05","D_EMP05","D_HH05"}
	Opts.Global.Method = "Formula"
	Opts.Global.Parameter = {"POP05/Area05","EMP05/Area05","HH05/Area05"}
	ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
	
	//read the areatype table 
	speedview = OpenTable("ATYPE","FFB",{Args.[atype],})
	atype=GetDataVectors("ATYPE|",{"AreaType","Formula"},)
	
	// calculate the utility
	for i=1 to atype[1].length do
		a=atype[1][i]+"_exp"
		b=atype[2][i]
		CreateExpression(tazname,a,b,)
		if i<>atype[1].length then sum_a=sum_a+a+"+" else sum_a=sum_a+a
	end
	
	// sum the utility
	CreateExpression(tazname, "sum_exp",sum_a,)
		
	// calculate the probability for each area type
	for i=1 to atype[1].length do
		Opts = null
		Opts.Input.[Dataview Set] = {taz_db+"|"+tazname, tazname}
		Opts.Global.Fields = {atype[1][1],atype[1][2],atype[1][3],"Rural"}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = {atype[1][1]+"_exp/(1+sum_exp)",atype[1][2]+"_exp/(1+sum_exp)",atype[1][3]+"_exp/(1+sum_exp)","1-CBD-Urban-Su"}
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	end		
	
	// max(p) of the area type
	max1="Max(CBD, Urban)"
	max2="Max(SU,Rural)"
	max_all="Max(max1,max2)"
	CreateExpression(tazname, "max1",max1,)
	CreateExpression(tazname, "max2",max2,)
	CreateExpression(tazname, "max_all",max_all,)
		
	//fill the area type
	Opts = null
	Opts.Input.[Dataview Set] = {taz_db+"|"+tazname, tazname}
	Opts.Global.Fields = {"Predict"}
	Opts.Global.Method = "Formula"
	Opts.Global.Parameter = {"if max_all=CBD then 'CBD' else if max_all=Urban then 'URBAN' else if max_all=Su then 'SU' else if max_all=Rural then 'RURAL' else 'RURAL'"}
	ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit


	//UpdateProgressBar("Area Type - Tagging Area Type to Network -(inside of the TAZs)", ) //TransCAD6
	//tag the area type
	//Opts = null
	//Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer,  "selection", "select * where id>0"}
	//Opts.Input.[Tag View Set] = {taz_db+"|"+tazname,  tazname}
	//Opts.Global.Fields = {llayer+".MOD_AREA"}
	//Opts.Global.Method = "Tag"
	//Opts.Global.Parameter = {"Value", tazname, tazname+".Predict"}
	//ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	//if !ret_value then goto quit
	
	UpdateProgressBar("Area Type - Tagging Area Type to Network -(inside of the TAZs)", ) //TransCAD8
	//tag the area type
	vw_set = RunMacro("TCB Create View Set", hwy_db+"|"+llayer, llayer, "Selection", "Select * where ID>0")
    ok = (vw_set <> null)
    if !ok then goto quit
    tag_set = RunMacro("TCB Create View Set", taz_db+"|"+tazname,  tazname)
    ok = (tag_set <> null)
    if !ok then goto quit
    TagLayer("Value", vw_set, llayer+".MOD_AREA", tag_set, tazname+".Predict")

    //tag node layer with TAZ id
	// Opts = null // TransCAD6
	//Opts.Input.[Dataview Set] = {hwy_db+"|"+nlayer, llayer,  , }
	//Opts.Input.[Tag View Set] = {taz_db+"|"+tazname,  tazname}
	//Opts.Global.Fields = {nlayer+".TAZID_Stop_New"}
	//Opts.Global.Method = "Tag"
	//Opts.Global.Parameter = {"Value", tazname, tazname+".ID_NEW"}
	//ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	//if !ret_value then goto quit
	
	vw_set = RunMacro("TCB Create View Set", hwy_db+"|"+nlayer, llayer,  , ) //TransCAD8
    ok = (vw_set <> null)
    if !ok then goto quit
    tag_set = RunMacro("TCB Create View Set", taz_db+"|"+tazname,  tazname)
    ok = (tag_set <> null)
    if !ok then goto quit
    TagLayer("Value", vw_set, nlayer+".TAZID_Stop_New", tag_set, tazname+".ID")

	UpdateProgressBar("Area Type - Tagging Area Type to Network (outside of the TAZs)", )
	SetLayer(llayer)
	qry="select * where MOD_AREA=null"
	n=SelectByQuery(llayer, "Several", qry,)
	
	if n>0 then do
		DropLayer(temp_map, "Centroids")
	
		//Export the centroid points again, so the no tag link can tag to centroid points instead
		ExportGeography(tazname+"|",Scen_Dir+"\\outputs\\ATCentroids.dbd",   
		{{"Centroid","True"},
		{"Field Spec",field_specs},
		{"Field Name",field_names},
		{"ID Field",tazname+".ID"},
		{"Label","Centroids"},
		{"Layer Name","Centroids"}})
		
		temp_layer = AddLayer(temp_map,"Centroids",Scen_Dir+"\\outputs\\ATCentroids.dbd","Centroids")
		
		SetLayer(llayer)
		qry="select * where MOD_AREA=null"
		n=SelectByQuery(llayer, "Several", qry,)
		if n>0 then do
			
			// 1 tag to centroids if no tag result
			//Opts = null //TransCAD6
			//Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "selection", "select * where MOD_AREA=null "}
			//Opts.Input.[Tag View Set] = {Scen_Dir+"\\outputs\\ATCentroids.dbd"+"|Centroids",  "Centroids"}
			//Opts.Global.Fields = {llayer+".MOD_AREA"}
			//Opts.Global.Method = "Tag"
			//Opts.Global.Parameter = {"Value", "Centroids", "Centroids.Predict"}
			//ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
			//if !ret_value then goto quit
			
			vw_set = RunMacro("TCB Create View Set", hwy_db+"|"+llayer, llayer, "selection", "select * where MOD_AREA=null ") //TransCAD8
			ok = (vw_set <> null)
			if !ok then goto quit
			tag_set = RunMacro("TCB Create View Set", Scen_Dir+"\\outputs\\ATCentroids.dbd"+"|Centroids",  "Centroids")
			ok = (tag_set <> null)
			if !ok then goto quit
			TagLayer("Value", vw_set, llayer+".MOD_AREA", tag_set, "Centroids.Predict")
						
		end
		
		// 2 rural if no tag result
		SetLayer(llayer)
		qry="select * where MOD_AREA=null"
		n=SelectByQuery(llayer, "Several", qry,)
		if n>0 then do
			
			Opts = null
			Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "selection", "select * where MOD_AREA=null"}
			Opts.Global.Fields = {"MOD_AREA"}
			Opts.Global.Method = "Value"
			Opts.Global.Parameter = "'Rural'"
			ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
			if !ret_value then goto quit
		end
	end
	
	dim selections_class[6]	
	selections_class[1]="select * where (Func_Class=1 or Func_Class=11 or Func_Class=20)"
	selections_class[2]="select * where (Func_Class=12)"
	selections_class[3]="select * where (Func_Class=2 or Func_Class=14 or Func_Class=6 or Func_Class=16) and SPD_LMT>=45"
	selections_class[4]="select * where (Func_Class=2 or Func_Class=14 or Func_Class=6 or Func_Class=16) and SPD_LMT<45 "
	selections_class[5]="select * where (Func_Class=7 or Func_Class=8 or Func_Class=17)"
	selections_class[6]="select * where (Func_Class=9 or Func_Class=19 or CCSTYLE=99 or Func_Class=21 or Func_Class=22 or Func_Class=97)"
	
	class_names={"INTERSTATE","FREEWAY","ART45","ART","COLLECTOR","LOCAL"}
	
	for i=1 to selections_class.length do
    Opts = null
    Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "Selection", selections_class[i]}
    Opts.Global.Fields = {"MOD_CLASS"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {class_names[i]}

    ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
	end
	


	AREATYPE={"CBD", "URBAN", "SU", "RURAL"}
	AREASPEED={30,30,30,30}
	
	for i=1 to AREATYPE.length do
    Opts = null
    Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "Selection", "Select * where CCSTYLE=99 and MOD_AREA='"+AREATYPE[i]+"'"}
    Opts.Global.Fields = {"SPD_LMT"}
    Opts.Global.Method = "Value"
    Opts.Global.Parameter = {AREASPEED[i]}

    ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
	end

	endtime = RunMacro("RuntimeLog", {"Initialization - Area Type", starttime})
	ret_value = 1
	quit:
	CloseMap("temp")
	return(ret_value)
endMacro


// 1. Factors to caculate the capacity :CAP_FF_1
// 2. TOD capacity :CAP_FF_2
// 3. FF speed using the FF table and Calculate the congested speed for the first distribution by TOD :CAP_FF_3
// 4. Alpha and beta
macro "CAP_FF" (Args)// Initialization 2 - Capacity and FF speed
	shared prj_dry_run,  Scen_Dir
		
	if prj_dry_run then return(1)

	starttime = RunMacro("RuntimeLog", {"Initialization - Capacity and FF speed", null})
	RunMacro("HwycadLog", {"1.1 Initialization.rsc", "Capacity and FF Speed"})

	// Input highway
   hwy_db = Args.[hwy db]
	demographics = Args.[taz table]	
	taz_db = Args.[taz]
	
	layers = GetDBlayers(hwy_db)
   llayer = layers[2]
   db_linklyr = highway_layer + "|" + llayer
   
   temp_map = CreateMap("temp",{{"scope",Scope(Coord(-80000000, 44500000), 200.0, 100.0, 0)}})
   temp_layer = AddLayer(temp_map,llayer,hwy_db,llayer)
	SetView(llayer)
	RunMacro("TCB Init")

	//**************************************
	//*  CAP_FF_1 Select and fill the cap vars   *
	//**************************************
	// 1. Interstate/Freeway Capacity Equations (Functional classification = 1, 11, 12)
	// 2. Principal Arterial Capacity Equations (Functional classification = 2 or 14)
	// 3. Minor Arterial Capacity Equations (Functional classification = 6 or 16)
	// 4. Collector Road Capacity Equations (Functional classification = 7, 8, or 17)
	// 5. Ramp Capacity Equations (Functional classification = 20, 21, 22)
	// 6. Local Road Capacity Equations (Functional classification = 9, 19, 99)
	
	CAP_FF_1:
	UpdateProgressBar("Link Hourly Capacity", )
	capacity=OpenTable("capacity","FFB", {Args.[Capacity Table],})
	
	//Capacity table Field names
	condition1={	"Func_Class",
		"Lanes",
		"W_Shoulder_Out1",
		"W_Shoulder_Out2",
		"W_Lane",
		"TY_TERRAIN",
		"Med",
		"MOD_AREA",
		"Signal1",
		"Signal2",
		"CTL",
		"PARK"}
	
	//Network Field Names
	condition2={	"Func_Class",
		"Lanes",
		"W_Shoulder_Out",
		"W_Shoulder_Out",
		"W_Lane",
		"TY_TERRAIN",
		"Med",
		"MOD_AREA",
		"Signal",
		"Signal",
		"CTL",
		"PARK"}
	
	//Capacity Coefficients
	coeff=
	{	"c",
		"Fw",
		"Fhv",
		"Fp",
		"Fe",
		"Fd",
		"Fsd",
		"Fsc",
		"Fctl",
		"Fpark",
		"Ft",
		"Fa"
		}
	
	//reads the capacity table
	v_condition=getdatavectors(capacity+"|", condition1,)
	v_coeff=getdatavectors(capacity+"|", coeff,)

	//dim queries (316 conditions in the Capacity table)
	dim queries[v_condition[1].length]
 
	//build queries based on the condition
	for i=1 to queries.length do
		//subs = ParseString("Aaron LaClair Brandon", " ")
		
		subs= ParseString(v_condition[1][i], ",")
		if subs.length=1 then queries[i]="Select * where Func_Class=" + v_condition[1][i] //query head for all the functional classes 
			
		if subs.length>1 then do
			for k=1 to subs.length do
				if k=1 then queries[i]="Select * where (Func_Class=" + subs[k] //query head for all the functional classes 
				if k>1 then queries[i] =queries[i]+ " or Func_Class=" + subs[k]
				if k=subs.length then queries[i] =queries[i]+")"
			end
		end
		
		for j=2 to v_condition.length do //query head + conditions
			if v_condition[j][i] <> null then queries[i]=queries[i] + " and " + condition2[j]+ v_condition[j][i]
		end
	end    
	
	SetView(llayer)
	UpdateProgressBar("Capacity and Speed - Fill the Capacity Coefficients", )
	
	// fill the coefficients to the line layer dataview
	for i=1 to queries.length do //316
		UpdateProgressBar("Capacity and FF - fill the coefficients to the line layer dataview " + i2s(i) + " of  "+ i2s(queries.length), )
		n = SelectByQuery("selection", "Several", queries[i],) 
		
		if n>0 then do 
			for j=1 to coeff.length do //11 coeff
				if v_coeff[j][i]<>null then do
					fields=fields+{coeff[j]}
					parameters=parameters+{v_coeff[j][i]}
				end
			end
			//fill the variables to the selected records
			Opts = null
			Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "Selection", qry}
			Opts.Global.Fields = fields
			Opts.Global.Method = "Formula"
			Opts.Global.Parameter = parameters
			ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts)
			if !ret_value then goto quit
			fields=null
			parameters=null
		end
	end
	
	//**************************************
	//*  CAP_FF_2 Calculate the Capacity	   *
	//**************************************
	//calculate the capacity with the factors, if the factor=null then 1
	//CreateExpression("all data with ramp","Fp2","if Fp<>null then Fp else 1",)
	
	CAP_FF_2:
	UpdateProgressBar("Capacity and Speed - Capacity", )
	
	//if coefficient=null then 1
	factors={"Fw","Fhv","Fp","Fe","Fd","Fsd","Fsc","Fctl","Fpark","Ft","Fa"}
	for i=1 to factors.length do
		a=llayer
		b=factors[i]+"2"
		c="if "+factors[i]+"<>null then "+factors[i]+" else 1"
		CreateExpression(a,b,c,)
	end

	// klm period_factor={"11",		"1.6",		"2.5",		"2.3",		"3.6"} Daily, AM, MD PM OP
	//period_factor={"11","1.6","2.6","2.1","3.7"}
	period_factor={"11","1.7","3.1","2.4","3.8"}

	qryset={"Select * where dir=0","Select * where dir=1","Select * where dir=-1"}
	dim fields[2]
	dim parameters[3]
	fields[1]={"capacity_daily_AB",	"capacity_am_AB",	"capacity_md_AB",	"capacity_pm_AB",	"capacity_op_AB"} //AB fields
	fields[2]={"capacity_daily_BA",	"capacity_am_BA",	"capacity_md_BA",	"capacity_pm_BA",	"capacity_op_BA"} //BA fields
	parameters[1]={"0.5*lanes*capacity*"+period_factor[1],"0.5*lanes*capacity*"+period_factor[2],	"0.5*lanes*capacity*"+period_factor[3],"0.5*lanes*capacity*"+period_factor[4],"0.5*lanes*capacity*"+period_factor[5]}
	parameters[2]={"lanes*capacity*"+period_factor[1],"lanes*capacity*"+period_factor[2],	"lanes*capacity*"+period_factor[3],"lanes*capacity*"+period_factor[4],"lanes*capacity*"+period_factor[5]}
	parameters[3]={"lanes*capacity*"+period_factor[1],"lanes*capacity*"+period_factor[2],	"lanes*capacity*"+period_factor[3],"lanes*capacity*"+period_factor[4],"lanes*capacity*"+period_factor[5]}
	

	for i=1 to 3 do // direction 0, 1, and -1
		Opts = null
		Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "Selection", qryset[i]}
		if i=1 then Opts.Global.Fields = {"capacity"}+fields[1]+fields[2] //dir=0
		if i=2 then Opts.Global.Fields = {"capacity"}+fields[1] //dir=1
		if i=3 then Opts.Global.Fields = {"capacity"}+fields[2] //dir=-1	
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter ={"c*Fw2*Fhv2*Fp2*Fe2*Fd2*Fsd2*Fsc2*Fctl2*Fpark2*Ft2*Fa2"}+parameters[i]
		if i=1 then Opts.Global.Parameter ={"c*Fw2*Fhv2*Fp2*Fe2*Fd2*Fsd2*Fsc2*Fctl2*Fpark2*Ft2*Fa2"}+parameters[i]+parameters[i]
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts)
		if !ret_value then goto quit
	end
	
	//**************************************
	//*  CAP_FF_3 FF and init Speed			   *
	//**************************************
	//16 classes, 5 selections
	//Interstate = 1,11,20
	//Freeway =12
	//ART>=45 = 2, 14, 6, 16
	//ART<45 = 2, 14, 6, 16
	//COLLECTOR = 7,8,17
	//LOCAL 9,19, 99,21,22
	
	CAP_FF_3:
	UpdateProgressBar("Capacity and Speed - Speed", )
	// Input Files
	fftableview = OpenTable("FFTABLE","FFB",{Args.[ff],})
	
	ff=GetDataVectors("FFTABLE|",{"CBD","URBAN","SUBURBAN","RURAL"},) //1-7 FF SPD, 8-14 AM, 15-21 MD, 22-28 PM, 29-35 OP, initial congestion speed by TOD
	
	//select functional class by area type by direction for Free Flow/Initial Congestion Speed by time of day
	dim selections_class[7]	
	selections_class[1]="select * where (Func_Class=1 or Func_Class=11 or Func_Class=12 or Func_Class=20) and MOD_AREA='"
	selections_class[2]="select * where Func_Class=12 and MOD_AREA='"
	selections_class[3]="select * where (Func_Class=2 or Func_Class=14 or Func_Class=6 or Func_Class=16) and SPD_LMT>=45  and MOD_AREA= '"
	selections_class[4]="select * where (Func_Class=2 or Func_Class=14 or Func_Class=6 or Func_Class=16) and SPD_LMT<45 and MOD_AREA='"
	selections_class[5]="select * where (Func_Class=7 or Func_Class=8 or Func_Class=17) and MOD_AREA='"
	selections_class[6]="select * where (Func_Class=9 or Func_Class=19 or Func_Class=21 or Func_Class=22 or Func_Class=97) and MOD_AREA='"
	selections_class[7]="select * where CCSTYLE=99 and MOD_AREA='"
	selections_atype={"CBD'","URBAN'", "SU'","RURAL'"}
	selections_dir={" and dir=0"," and dir=1"," and dir=-1"}
	
	for i=1 to selections_class.length do // Interstate, FREEWAY, ART45, ART, COLLECTOR, LOCAL
		for j=1 to selections_atype.length do //"CBD","URBAN", "SU","RURAL"
			for k=1 to selections_dir.length do // dir 0 1 -1
				qry=selections_class[i]+selections_atype[j]+selections_dir[k]
				n=SelectByQuery("Selection", "Several", qry, )
				if n>0 then do
					Opts = null
					Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "Selection"}
					Opts.Global.Method = "Formula"
					
					if k=1 then do //direction 0
						Opts.Global.Fields = {
							"SPD_FF_AB", 
							"SPD_AM_AB", 
							"SPD_MD_AB",
							"SPD_PM_AB",
							"SPD_OP_AB",
		
							"time_FF_AB", 
							"time_AM_AB", 
							"time_MD_AB",
							"time_PM_AB",
							"time_OP_AB",
							
							"SPD_FF_BA", 
							"SPD_AM_BA", 
							"SPD_MD_BA",
							"SPD_PM_BA",
							"SPD_OP_BA",
		
							"time_FF_BA", 
							"time_AM_BA", 
							"time_MD_BA",
							"time_PM_BA",
							"time_OP_BA"
							}
						
						Opts.Global.Parameter = {
							"if Func_Class=97 then SPD_LMT else "+ff[j][i]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+7]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+14]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+21]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+28]+"*SPD_LMT",
			
							"(Length/SPD_FF_AB)*60",
							"(Length/SPD_AM_AB)*60",
							"(Length/SPD_MD_AB)*60",
							"(Length/SPD_PM_AB)*60",
							"(Length/SPD_OP_AB)*60",
							
							"if Func_Class=97 then SPD_LMT else "+ff[j][i]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+7]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+14]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+21]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+28]+"*SPD_LMT",
		
							"(Length/SPD_FF_BA)*60",
							"(Length/SPD_AM_BA)*60",
							"(Length/SPD_MD_BA)*60",
							"(Length/SPD_PM_BA)*60",
							"(Length/SPD_OP_BA)*60"
						}
					end
					
					if k=2 then do //direction 1
						Opts.Global.Fields = {
						"SPD_FF_AB", 
						"SPD_AM_AB", 
						"SPD_MD_AB",
						"SPD_PM_AB",
						"SPD_OP_AB",
	
						"time_FF_AB", 
						"time_AM_AB", 
						"time_MD_AB",
						"time_PM_AB",
						"time_OP_AB"
						}
					
					Opts.Global.Parameter = {
							"if Func_Class=97 then SPD_LMT else "+ff[j][i]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+7]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+14]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+21]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+28]+"*SPD_LMT",
		
						"(Length/SPD_FF_AB)*60",
						"(Length/SPD_AM_AB)*60",
						"(Length/SPD_MD_AB)*60",
						"(Length/SPD_PM_AB)*60",
						"(Length/SPD_OP_AB)*60"
						}
					end	
					
					if k=3 then do //direction -1
					Opts.Global.Fields = {
						"SPD_FF_BA", 
						"SPD_AM_BA", 
						"SPD_MD_BA",
						"SPD_PM_BA",
						"SPD_OP_BA",
	
						"time_FF_BA", 
						"time_AM_BA", 
						"time_MD_BA",
						"time_PM_BA",
						"time_OP_BA"
						}
					
					Opts.Global.Parameter = {
							"if Func_Class=97 then SPD_LMT else "+ff[j][i]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+7]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+14]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+21]+"*SPD_LMT", 
							"if Func_Class=97 then SPD_LMT else "+ff[j][i+28]+"*SPD_LMT",
	
						"(Length/SPD_FF_BA)*60",
						"(Length/SPD_AM_BA)*60",
						"(Length/SPD_MD_BA)*60",
						"(Length/SPD_PM_BA)*60",
						"(Length/SPD_OP_BA)*60"
						}
					end
					
					ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts)
					if !ret_value then goto quit
				end
			end
		end
	end

    //**************************************
	//*  CAP_FF_4 Walk Speed							   *
	//**************************************
	CAP_FF_4:
	UpdateProgressBar("Walk Speed", )
	walkspeed=Args.[WalkSpeed]
	Opts = null
	Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, }
	Opts.Global.Fields = {"WalkTime"}
	Opts.Global.Method = "Formula"
	Opts.Global.Parameter = "if WalkLink<>99999 then length/"+i2s(walkspeed)+" else 999"
	ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts)
	if !ret_value then goto quit
    
	//**************************************
	//*  CAP_FF_5 Alpha and Beta				   *
	//**************************************
	//FREEWAY = 1,11,12,20
	//Mutiple lane highways the rest
	//Centroid connector fclass=99
	//the rest, alpha=null
	//NCHRP 716- Table 4.25
	
	CAP_FF_5:
	UpdateProgressBar("Capacity and Speed - Alpha and Beta", )
	
	dim selections_area[4]
	selections_area[1]=" and MOD_AREA='CBD'"
	selections_area[2]=" and MOD_AREA='URBAN'"
	selections_area[3]=" and MOD_AREA='SU'"
	selections_area[4]=" and MOD_AREA='RURAL'"

	BPRVIEW= OpenTable("BPR","FFB",{Args.[BPR_TAB],})
	BPR_VEC=GetDataVectors(BPRVIEW+"|",{"AreaType","func_code","FFSPD1", "FFSPD2", "ALPHA","BETA"},)
		
	dim bpr_qry[BPR_VEC[1].length*2] //36 conditions, 4 area types, 9 functional classes
	dim alpha_beta[bpr_qry.length,2]
	
	count=1
	for d=1 to 2 do //direction, 1= direction 1 or 0, 2= direction -1
		for a=1 to selections_area.length do //4 area types
			for i=1 to (BPR_VEC[1].length/selections_area.length) do //total records divided by number of area types
				temp_qry="Select * where "
				
				//get the functional classes
				subs=ParseString(BPR_VEC[2][i],",") 
				
				//add functional class conditions
				for j=1 to subs.length do
					if j=1 then temp_qry=temp_qry+ " (func_class="+subs[j]
					if j>1 then temp_qry=temp_qry+ " or func_class="+subs[j]
					if j=subs.length then temp_qry=temp_qry+ ")"
				end
				
				//add FF speed conditions
				if d=1 then do //direction 0 and 1
					if BPR_VEC[3][count]<>null then temp_qry=temp_qry+" and (DIR=1 or DIR=0) and SPD_FF_AB"+BPR_VEC[3][count]
					if BPR_VEC[4][count]<>null then temp_qry=temp_qry+" and SPD_FF_AB"+BPR_VEC[4][count]
					alpha_beta[count][1]=BPR_VEC[5][count]
					alpha_beta[count][2]=BPR_VEC[6][count]
				end
				
				if d=2 then do //direction 0 and 1
					if BPR_VEC[3][count-BPR_VEC[1].length]<>null then temp_qry=temp_qry+" and DIR=-1  and SPD_FF_BA"+BPR_VEC[3][count-BPR_VEC[1].length]
					alpha_beta[count][1]=BPR_VEC[5][count-BPR_VEC[1].length]
					alpha_beta[count][2]=BPR_VEC[6][count-BPR_VEC[1].length]
				end
				
				//add area type conditions
				temp_qry=temp_qry+selections_area[a]
				
				//set the condition
				bpr_qry[count]=temp_qry
				
				
				count=count+1
			end
		end
	end
	
	for i=1 to bpr_qry.length do
		n=SelectByQuery("Selection", "Several", bpr_qry[i], )
		if n>0 then do
			Opts = null
			Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer, "Selection"}
			Opts.Global.Fields = {"alpha","Beta"}
			Opts.Global.Method = "Formula"
			Opts.Global.Parameter = {r2s(alpha_beta[i][1]),r2s(alpha_beta[i][2])}
			ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts)
			if !ret_value then goto quit
		end
	end	

	endtime = RunMacro("RuntimeLog", {"Initialization - Capacity and FF speed", starttime})
	ret_value = 1
	quit:
	CloseMap("temp")
	return(ret_value)
endmacro