
//**************************************
//*      					Part 4  					   	        *
//*					Freight Movement						 *
//**************************************
macro "Freight Movement" (Args)
	/*
	freight_1:  //create (zone_district)district.bin with the TAZ data 
	freight_2:  //caclulate the taz raw weights
	freight_3:  //aggregate the taz data to the sum_distric file and calculate the weight
	freight_4:  //create weight matrixes
	freight_5:  //disaggregate the transearch districs to TAZ
	freight_6:  //Heavy truck external assignment
	
	=====Calculate the weights for the Disaggregation
	1. Export the TAZ with the EMP and HH info to "zone_district" (outputs\district.bin)
	2. Add EMP_Formula and Weight field to the "zone_district" table
	3. Add truck external station IDs with 0 EMP and HH to the "zone_district" table
	4. Fill the formula to the table "1*EMP_ARG+1*EMP_MANU+1*EMP_RET+1*EMP_OFFICE+ 1* HH10"
	5. Aggregate the table by district to "SumDistrict" table
	6. Weight= formula/(sumed formula by district)
	
	
	=====Update_Matrix
	7. create new matrix - "update_mtx" district ID by District ID(TAZ+external)
		update_mtx = Scen_Dir + "outputs\\FREIGHT_MODEL_"+horizon[year]+"_DISTRICT_update.mtx"  
	8. create currency zone by zone for both O and D
	9. Add Weight_O and Weight_D field. 
	10. Fill Weight_O and Weight with value "1"
	11. apply the weight to all origin (colum, row="no")
	12. apply the weight to all destination (row, row="yes")
	13. No weights applied to EE
	
	=====Finalization
	14. Sum all the trips from different matricies to "Table" Matrix
	15. Update the network MU fields and the network for the preload process
	*/
	
	shared prj_dry_run, Scen_Dir
   // if prj_dry_run then return(1)

    // Input highway and TAZ files. 
   hwy_db = Args.[hwy db]
	
	taz_db = Args.[taz]
	
	layers = GetDBlayers(hwy_db)
   llayer = layers[2]
   nlayer = layers[1]
   
   db_linklyr = highway_layer + "|" + llayer
   
   temp_map = CreateMap("temp",{{"scope",Scope(Coord(-80000000, 44500000), 200.0, 100.0, 0)}})
   temp_layer = AddLayer(temp_map,llayer,hwy_db,llayer)
   temp_layer = AddLayer(temp_map,nlayer,hwy_db,nlayer)

   	//Add TAZ layer
   	layers = GetDBlayers(taz_db)
   tazname = layers[1]
	temp_layer =AddLayer("temp",tazname,taz_db,tazname)

	
	UpdateProgressBar("create (zone_district)district.bin with the TAZ data ", )
	freight_1:  //create (zone_district)district.bin with the TAZ data 
	
	//Files used for MU truck expansion   
	TAZNAME=SplitPath(Args.[taz_db])
	zone_table= TAZNAME[1]+TAZNAME[2]+TAZNAME[3]+".bin"
	zone_district= Scen_Dir+ "outputs\\district.bin"
	sum_district= Scen_Dir + "outputs\\SumDistrict.bin"
	mtx_table= Args.[District Multi Unit Exter]
	update_mtx = Args.[MU OD Matrix]
    IDTable = Args.[IDTable]    
	
	
	//goto freight_6//debug
	SetLayer (nlayer)
	SetView(nlayer)
	vw = GetView()
	
	// export taz with the fields specified
	n1 = SelectByQuery("selection", "Several", "Select * where ccstyle=97 or ccstyle=99",) //97=external stations for freight
	//ExportView(vw+"|selection", "FFB", zone_district,{"ID","ID","CCSTYLE", "TRANSID"},)
    ExportView(vw+"|selection", "FFB", zone_district,{"ID","CCSTYLE", "TRANSID"},)
	
	//modify table to add EMP Formula and Dist_Weight
	view = OpenTable("district", "FFB", {zone_district,})
	strct1 = GetTableStructure(view)
	 	
	for i = 1 to strct1.length do
	     strct1[i] = strct1[i] + {strct1[i][1]}
	end
	 	
	strct2 = strct1 + {
	 		{"EMP_Formula", "Real", 12, 3, "True", , , , , , , null}, 
	 		{"Weight", "Real", 12, 4, "True", , , , , , , null},
	 		{"EMP_ARG", "Real", 12, 4, "True", , , , , , , null},
	 		{"EMP_MANU", "Real", 12, 4, "True", , , , , , , null},
	 		{"EMP_RET", "Real", 12, 4, "True", , , , , , , null},
	 		{"EMP_OFFICE", "Real", 12, 4, "True", , , , , , , null},
	 		{"EMP_TRANS", "Real", 12, 4, "True", , , , , , , null},
	 		{"HH10", "Real", 12, 4, "True", , , , , , , null},
	 		{"Area", "Real", 12, 4, "True", , , , , , , null}
	 		}
	ModifyTable(view, strct2)
	
	//fill the district bin with the TAZ info
	RunMacro ("TCB Init")
	Opts = null
	Opts.Input.[Dataview Set] = {{Args.[taz]+"|"+tazname, zone_district, {"ID_NEW"}, {"ID"}}, "TAZ+DISTRICT"}
	Opts.Global.Fields = {"district.Area","district.EMP_ARG","district.EMP_MANU","district.EMP_RET","district.EMP_OFFICE","district.EMP_TRANS","district.HH10"}
	Opts.Global.Method = "Formula"
	Opts.Global.Parameter = {"["+tazname+"].Area","["+tazname+"].EMP_ARG","["+tazname+"].EMP_MANU","["+tazname+"].EMP_RET","["+tazname+"].EMP_OFFICE","["+tazname+"].EMP_TRANS","["+tazname+"].HH10"}
	ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
	
	UpdateProgressBar("caclulate the taz raw weights ", )
	freight_2:  //caclulate the taz raw weights
	//fill zonal data with EMP Formula to zone_district(taz)
	RunMacro ("TCB Init")
	Opts = null
	Opts.Input.[Dataview Set] = {zone_district, view}
	Opts.Global.Fields = {"EMP_Formula"}
	Opts.Global.Method = "Formula"
	// 10% increase for II
	Opts.Global.Parameter = {"nz(0.174*EMP_ARG+0.104*EMP_TRANS+0.104*EMP_MANU+0.065*EMP_RET+0.009*EMP_OFFICE+ 0.038* HH10)"}
	ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
	
	
	UpdateProgressBar("aggregate the taz data to the sum_distric file and calculate the weight", )
	freight_3:  //aggregate the taz data to the sum_distric file and calculate the weight
	//Aggregated table by district(frt_dist)
	rslt = AggregateTable("SumDistrict", view+"|", "FFB", sum_district, "TRANSID", {{"EMP_Formula","sum", },{"Area","sum", }}, null)
	
	//open the sum district table
	OpenTable("SumDistrict", "FFB", {sum_district,})

	//calculate the weights for all TAZs
    Opts = null
    Opts.Input.[Dataview Set] = {{zone_district, sum_district, {"TRANSID"}, {"TRANSID"}}, "district+SumDistrict"}
    Opts.Global.Fields = {"Weight"}
    Opts.Global.Method = "Formula"
    Opts.Global.Parameter = "district.EMP_Formula/ SumDistrict.EMP_Formula"
    //Opts.Global.Parameter = "if district.EMP_Formula<>null then district.EMP_Formula/ SumDistrict.EMP_Formula else district.Area/SumDistrict.Area"
    ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
	
	//weight of 1 for all externals
	 Opts = null
    Opts.Input.[Dataview Set] = {{zone_district, sum_district, {"TRANSID"}, {"TRANSID"}}, "district+SumDistrict"}
    Opts.Global.Fields = {"Weight"}
    Opts.Global.Method = "Formula"
    Opts.Global.Parameter = "if ccstyle=97 then 1 else Weight"
    ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
	
	//create new matrix, view=district table
	mat =CreateMatrix({view+"|", view+".id", "ZONE"}, {view+"|", view+".id", "ZONE"},
	     {{"Label","MUOD"},{"File Name", update_mtx}, {"Type", "Float"}})
	
	mc = CreateMatrixCurrency(mat, "Table", "ZONE", "ZONE", )
	
	UpdateProgressBar("create the weight matrixes", )
	freight_4:  //create weight matrixes
	weights={"Weight_O","Weight_D"}
	
	//apply weight for ETRK by rows and apply weight for ITRK by cols
	for i=1 to 2 do
		Opts = null
		Opts.Input.[Input Matrix] = update_mtx
		Opts.Input.[New Core] = weights[i]
		ret_value = RunMacro("TCB Run Operation", "Add Matrix Core", Opts, &Ret)
		if !ret_value then goto quit
		
	    mc = RunMacro("TCB Create Matrix Currency", update_mtx, weights[i], "ZONE", "ZONE")
	    ok = (mc <> null)
	    if !ok then goto quit
	    mc := 1

	     Opts = null
	     Opts.Input.[Matrix Currency] = {update_mtx, weights[i], "ZONE","ZONE"}
	     Opts.Input.[Source Matrix Currency] = {update_mtx, weights[i], "ZONE", "ZONE"}
	     Opts.Input.[Data Set] = {zone_district, "district"}
	     Opts.Global.Method = 12
	     Opts.Global.[Fill Option].[ID Field] = "district.ID"
	     Opts.Global.[Fill Option].[Value Field] = "district.Weight"
	     if weights[i]="Weight_O" then Opts.Global.[Fill Option].[Apply by Rows] = "YES"
	     if weights[i]="Weight_D" then Opts.Global.[Fill Option].[Apply by Rows] = "NO"
	     Opts.Global.[Fill Option].[Missing is Zero] = "Yes"
	     ret_value = RunMacro("TCB Run Operation", "Fill Matrices", Opts, &Ret)
	     if !ret_value then goto quit
  	end  
  	
  	UpdateProgressBar("disaggregate the transearch districs to TAZ", )
  	freight_5:  //disaggregate the transearch districs to TAZ
  		//	mtx_table= Args.[District Multi Unit Exter]
		// update_mtx = Scen_Dir + "outputs\\FREIGHT_DISTRICT_update.mtx"  
		Opts = null
    	Opts.Input.[Input Matrix] = update_mtx
    	Opts.Input.[New Core] = "Demand (Through)"
    	ret_value = RunMacro("TCB Run Operation", "Add Matrix Core", Opts, &Ret)
    	
    	Opts = null
    	Opts.Input.[Input Matrix] = update_mtx
    	Opts.Input.[New Core] =  "Demand (Inbound)"
    	ret_value = RunMacro("TCB Run Operation", "Add Matrix Core", Opts, &Ret)
    	if !ret_value then goto quit

		Opts = null
    	Opts.Input.[Input Matrix] = update_mtx
    	Opts.Input.[New Core] =  "Demand (Outbound)"
    	ret_value = RunMacro("TCB Run Operation", "Add Matrix Core", Opts, &Ret)
    	if !ret_value then goto quit
    	
        // add a revised index to mtx_table - copy first
        
        m = OpenMatrix(mtx_table, )
        mc = CreateMatrixCurrency(m,, "ZONE", "ZONE", )
        outmat = Scen_Dir + "outputs\\temp_2010 district sub OD factored.mtx" 
        new_mat = CopyMatrix(mc,{{"File Name",outmat},{"Label", "New Matrix"},{"File Based", "Yes"},{"Indices", "Current"}})
        mtx_table=outmat
       
        m = OpenMatrix(mtx_table, )
        view = OpenTable("equivalancy", "FFB", {IDTable})
        new_index = CreateMatrixIndex("revised", m, "Both", view+"|", "ID", "NEWID",)
        m = Null
        
		mc1 = RunMacro("TCB Create Matrix Currency", update_mtx, "Weight_O", "ZONE", "ZONE")
		mc2 = RunMacro("TCB Create Matrix Currency", update_mtx, "Weight_D", "ZONE", "ZONE")
   		mc3 = RunMacro("TCB Create Matrix Currency", update_mtx, "Table", "ZONE", "ZONE")

	   	mc4 = RunMacro("TCB Create Matrix Currency", update_mtx, "Demand (Through)", "ZONE", "ZONE")
		mc5 = RunMacro("TCB Create Matrix Currency", update_mtx, "Demand (Inbound)", "ZONE", "ZONE")
		mc6 = RunMacro("TCB Create Matrix Currency", update_mtx, "Demand (Outbound)", "ZONE", "ZONE")

	   	mc7 = RunMacro("TCB Create Matrix Currency", mtx_table, "Demand (Through)", "revised", "revised")
		mc8 = RunMacro("TCB Create Matrix Currency", mtx_table, "Demand (Inbound)", "revised", "revised")
		mc9 = RunMacro("TCB Create Matrix Currency", mtx_table, "Demand (Outbound)", "revised", "revised")

		retmtx={mc1,mc2,mc3, mc4,mc5,mc6,mc7,mc8,mc9}
		
		for i=1 to retmtx.length do
			if retmtx[i]=null then goto quit
		end
	
		mc4 := mc7
		mc5 := mc2*mc8
		mc6 := mc1*mc9
		mc3 := mc4+mc5+mc6
	
	UpdateProgressBar("Heavy truck external assignment", )
	freight_6:  //Heavy truck external assignment
//Add Matrix Index for TAZ ids for MUOD matrix

    Opts = null
    Opts.Input.[Current Matrix] = update_mtx
    Opts.Input.[Index Type] = "Both"
    Opts.Input.[View Set] = {zone_district, "district", "Selection", "Select * where CCSTYLE=99"}
    Opts.Input.[Old ID Field] = {zone_district, "ID"}
    Opts.Input.[New ID Field] = {zone_district, "ID"}
    Opts.Output.[New Index] = "Internal"
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Index", Opts, &Ret)
    if !ret_value then goto quit

	//TOD
	Opts = null
    Opts.Input.[PA Matrix Currency] = {update_mtx, , , }
    Opts.Input.[Lookup Set] = {Args.[Hourly], "NashvilleHourly"}
    Opts.Field.[Matrix Cores] = {4, 5, 6}
    Opts.Field.[Adjust Fields] = {, , }
    Opts.Field.[Peak Hour Field] = {, , }
    Opts.Field.[Hourly AB Field] = {"DEP_EEMU", "DEP_IEMU", "DEP_IEMU"}
    Opts.Field.[Hourly BA Field] = {"RET_EEMU", "RET_IEMU", "RET_IEMU"}
    Opts.Global.[Method Type] = "PA to OD"
    Opts.Global.[Start Hour] = 0
    Opts.Global.[End Hour] = 3
    Opts.Global.[Cache Size] = 500000
    Opts.Global.[Average Occupancies] = {1.5, 1.5, 1.5}
    Opts.Global.[Adjust Occupancies] = {"No", "No", "No"}
    Opts.Global.[Peak Hour Factor] = {1, 1, 1}
    Opts.Flag.[Separate Matrices] = "Yes"
    Opts.Flag.[Convert to Vehicles] = {"No", "No", "No"}
    Opts.Flag.[Include PHF] = {"No", "No", "No"}
    Opts.Flag.[Adjust Peak Hour] = {"No", "No", "No"}
    Opts.Output.[Output Matrix].Label = "PA to OD"
    Opts.Output.[Output Matrix].[File Name] = Args.[Freight OD]
    ret_value = RunMacro("TCB Run Procedure", "PA2OD", Opts, &Ret)
	 if !ret_value then goto quit
	 	
	// Change Matrix Names
	freight={"Demand (Through) ","Demand (Inbound) ","Demand (Outbound) "}
	newfreight={"MUEE_","MUEI_","MUIE_"}
	periods1={"AM","MD","PM","OP"}
	periods2={"(0-1)","(1-2)","(2-3)","(3-4)"}
	
	for i=1 to freight.length do
		for p=1 to periods1.length do
		    Opts = null
		    Opts.Input.[Input Matrix] = Args.[Freight OD]
		    Opts.Input.[Target Core] = freight[i]+periods2[p]
		    Opts.Input.[Core Name] = newfreight[i]+periods1[p]
		    ret_value = RunMacro("TCB Run Operation", "Rename Matrix Core", Opts, &Ret)
		    if !ret_value then goto quit
		end
	end	

	//adding all centroid and external station ID to the index as "zone"
	Opts = null
    Opts.Input.[Current Matrix] = Args.[Freight OD]
    Opts.Input.[Index Type] = "Both"
    Opts.Input.[View Set] = {hwy_db+"|"+nlayer, nlayer, "Selection", "Select * where ccstyle=97 or ccstyle=98 or ccstyle=99"}
    Opts.Input.[Old ID Field] = {hwy_db+"|"+nlayer, "ID"}
    Opts.Input.[New ID Field] = {hwy_db+"|"+nlayer, "ID"}
    Opts.Output.[New Index] = "Zones"
    Opts.Global.[Allow non-matrix entries] = "True"
    ret_value = RunMacro("TCB Run Operation", "Add Matrix Index", Opts, &Ret)
    if !ret_value then goto quit 
	
    ret_value = 1
    quit:
   CloseMap("temp")
    return(ret_value)
endmacro