/* 
utility that process the moe for scenarios
�	Totoal Trips 
�	Total Population
�	Trips Per Person
�	VMT
�	VMT/Person
�	VHT
�	VHT/Person
�	Average Vehicle Speed
�	VMT @ LOS F (over the capacity)
�	% LOSF VMT
*/

macro "MOE1" (Args) //MOE 1 for the table
	RunMacro("TCB Init")
	RunMacro("HwycadLog", {"9.1 Utility.rsc", " Running MOE1"})
	
	shared Scen_Dir
	//create an MOE file
	MOE_file = Scen_Dir + "reports\\moe\\scenario_moe.csv"
	MOE = OpenFile(MOE_file,"w")
		
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
	
	//open the assignment result file
	rslt=OpenTable("Result", "FFB", {Args.[Assignment Result],})
		
	//join view
	net_rslt = JoinViews("net_rslt", llayer+".ID", "Result.ID",)

	//prepare daily trip table
	daily_matrix_file = Scen_Dir + "outputs\\DAILYOD.mtx"
	RunMacro("Build Daily Trip Table", daily_matrix_file, Args)
		
	//process matrix
	pa_matrix = OpenMatrix(daily_matrix_file,)
	
	//determine how many district fields are there (up to 10)
	taz_fields=GetViewStructure(tazname)
	
	districts={1,1,0,0,0,0,0,0,0,0} //flag for analysis, 10 districts max
/*	
	//look for fields with "MOE_DIST"
	for i=2 to 10 do
		for j=1 to taz_fields.length do
			if taz_fields[j][1]="MOE_DIST"+i2s(i) then do
				districts[i]=1
				j=taz_fields.length
			end
		end
	end
*/	
	//Lane Mile
	Opts = null
	Opts.Input.[View Set] = {hwy_db+"|"+llayer, llayer}
	Opts.Global.[Field Name] = "LANEMILE"
	Opts.Global.[Formula Text] = "lanes*length"
	Opts.Global.[Field Type] = "Real"
	ret_value = RunMacro("TCB Run Operation", "Formula Field", Opts, &Ret)
	if !ret_value then goto quit
	
	// ******************* district set loop ******************
	for n_dist_set=1 to districts.length do
        UpdateProgressBar("District Set "+ i2s(n_dist_set) +" of " +i2s(districts.length),)
		RunMacro("HwycadLog", {"              ", "District Set "+ i2s(n_dist_set) +" of " +i2s(districts.length)})
		
		if districts[n_dist_set]=0 then goto skip
		
		//reads and sort moe district names
		moe_data=GetDataVector(tazname+"|","MOE_DIST"+i2s(n_dist_set), {{"Sort Order",{{"MOE_DIST"+i2s(n_dist_set),"Ascending"}}}})
	
		//initial moe zone names
		moe_names={"Regional"}+{moe_data[1]}
		
		//get the district names: moe_names
		for i=2 to moe_data.length do
			if moe_data[i]<>moe_data[i-1] then moe_names=moe_names+{moe_data[i]}
		end
		
		//tag the line layer with district names //TransCAD6
		//Opts = null
		//Opts.Input.[Dataview Set] = {hwy_db+"|"+llayer, llayer,  "selection", "Select * where Assignment_Loc=1 and (County='47037' or County='47119' or County='47147' or County='47149' or County='47165' or County='47187' or County='47189')"}
		//Opts.Input.[Tag View Set] = {taz_db+"|"+tazname,  tazname}
		//Opts.Global.Fields = {llayer+".DIST_NAME"}
		//Opts.Global.Method = "Tag"
		//Opts.Global.Parameter = {"Value", tazname, tazname+".MOE_DIST"+i2s(n_dist_set)}
		//ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		//if !ret_value then goto quit

		UpdateProgressBar("tag the line layer with district names", ) //TransCAD8
		//tag district names
		vw_set = RunMacro("TCB Create View Set", hwy_db+"|"+llayer, llayer, "Selection", "Select * where Assignment_Loc=1 and (County='47037' or County='47119' or County='47147' or County='47149' or County='47165' or County='47187' or County='47189')")
		ok = (vw_set <> null)
		if !ok then goto quit
		tag_set = RunMacro("TCB Create View Set", taz_db+"|"+tazname,  tazname)
		ok = (tag_set <> null)
		if !ok then goto quit
		TagLayer("Value", vw_set, llayer+".DIST_NAME", tag_set, tazname+".MOE_DIST"+i2s(n_dist_set))
		
		// quicksum core
		check_quicksum=0		
		core_names = GetMatrixCoreNames(pa_matrix)
		for i=1 to core_names.length do
			if core_names[i]="QuickSum" then check_quicksum=1
		end
				
		if check_quicksum=0 then do
			AddMatrixCore(pa_matrix, "QuickSum")
		end
        
		//Sum the Cores
		RunMacro("TCB Init")
		Opts = null
		Opts.Input.[Input Currency] = {daily_matrix_file, "IICOM", "Rows", "Cols"}
		ret_value = RunMacro("TCB Run Operation", "Matrix QuickSum", Opts, &Ret)
		if !ret_value then goto quit
	
		//Temp Core for the calculation
		check_temp=0
		for i=1 to core_names.length do
			if core_names[i]="temp" then do 
				check_temp=1
				mc_temp = RunMacro("TCB Create Matrix Currency", daily_matrix_file, "temp", ,)
				mc_temp := 0
			end
		end
			
		if check_temp=0 then AddMatrixCore(pa_matrix, "temp")
		
		// ******** main loop  ********
		//if  n_dist_set=1 then WriteLine(MOE, "DistID"+"\t"+"DistName"+"\t"+ "Value")
		if  n_dist_set=1 then WriteLine(MOE, "Measure,"+"\t"+ "Value")
		
		for n_dist=1 to moe_names.length do
			UpdateProgressBar("Step "+i2s(n_dist)+" of " + i2s(moe_names.length) +" - "+ moe_names[n_dist],)
			RunMacro("HwycadLog", {"              ", "Step "+i2s(n_dist)+" of " + i2s(moe_names.length) +" - "+ moe_names[n_dist]})
			WriteLine(MOE, "*************"+moe_names[n_dist]+"*************")
		
			// Delete the new Index if it already exist
			matidxnames=GetMatrixIndexNames(pa_matrix)
			for i=1 to matidxnames[1].length do
				if matidxnames[1][i]= moe_names[n_dist] then DeleteMatrixIndex(pa_matrix, moe_names[n_dist])
			end
			
			// *************************** Step 1 : Total the trips from/to/within the districts ***************************
			//create the new index	if n_dist>=2
			if n_dist>=2 then do
				Opts = null
				Opts.Input.[Current Matrix] = daily_matrix_file
				Opts.Input.[Index Type] = "Both"
				Opts.Input.[View Set] = {taz_db+"|"+tazname, tazname, moe_names[n_dist], "Select * where MOE_DIST"+i2s(n_dist_set)+"='"+moe_names[n_dist]+"'"}
				Opts.Input.[Old ID Field] = {taz_db+"|"+tazname, "ID"}
				Opts.Input.[New ID Field] = {taz_db+"|"+tazname, "ID"}
				Opts.Output.[New Index] = moe_names[n_dist]
				ret_value = RunMacro("TCB Run Operation", "Add Matrix Index", Opts, &Ret)
				if !ret_value then goto quit
	
				//sum the matrix using the new index, total trips= EI + IE - II (cause it's double counting)
				//check if quicksum exisits in the PA matrix
	
				//calculate the total trips start or end at the location
				mc1 = RunMacro("TCB Create Matrix Currency", daily_matrix_file, "QuickSum", moe_names[n_dist],"Cols") //113099
				mc2 = RunMacro("TCB Create Matrix Currency", daily_matrix_file, "QuickSum", "Rows",moe_names[n_dist])  //202768
				mc3 = RunMacro("TCB Create Matrix Currency", daily_matrix_file, "QuickSum", moe_names[n_dist], moe_names[n_dist]) //28001
				
				mc1a = RunMacro("TCB Create Matrix Currency", daily_matrix_file, "temp", moe_names[n_dist],"Cols")
				mc2a = RunMacro("TCB Create Matrix Currency", daily_matrix_file, "temp", "Rows",moe_names[n_dist])
				mc3a = RunMacro("TCB Create Matrix Currency", daily_matrix_file, "temp", moe_names[n_dist], moe_names[n_dist])
				
				mcfinal=RunMacro("TCB Create Matrix Currency", daily_matrix_file, "temp","Rows" ,"Cols" ) //113099+202768-28001=287866
				mcfinal :=0
				
				mc1a:= nz(mc1a)+nz(mc1)
				mc2a:= nz(mc2a)+nz(mc2)
				mc3a:= nz(mc3a)-nz(mc3)
				
			end
			
			//reset the index
			mc0 = RunMacro("TCB Create Matrix Currency", daily_matrix_file, "IICOM","Rows" ,"Cols") //to reset the matrix
			
			//regional and district
			if n_dist=1 then do 
				SetMatrixIndex(pa_matrix, "Rows", "Cols") //reset index
				stat_array = MatrixStatistics(pa_matrix, {"QuickSum"}) 
				WriteLine(MOE, "Total Trips," + "\t" + r2s(stat_array.QuickSum.Sum))
			end
				
			if n_dist<>1 then do
				SetMatrixIndex(pa_matrix, "Rows", "Cols") //reset index 
				stat_array = MatrixStatistics(pa_matrix, {"Temp"})
				WriteLine(MOE, "Total Trips," + "\t" +i2s(r2i(stat_array.Temp.Sum)))
			end
			
			// *************************** Step 2 : Total Population**************************
			
			SetLayer(tazname)
			if n_dist=1 then qry="Select * Where ID <>null"
			if n_dist<>1 then qry="Select * Where MOE_DIST"+ i2s(n_dist_set)+"='"+moe_names[n_dist]+"'"
			
			SelectByQuery(moe_names[n_dist], "Several", qry,)
					
			pop=GetDataVector(tazname+"|"+moe_names[n_dist],"POP",)
			
			POPSUM=0
			for i=1 to pop.length do
				POPSUM=POPSUM+nz(pop[i])
			end
			
			WriteLine(MOE, "Total Population,"+"\t"+i2s(POPSUM))
	
				v_taz=GetDataVectors(tazname+"|"+moe_names[n_dist],
			{
				"ALLON",
				"ALLOFF",
				"EMP"
			},)
	
				// *************************** Step 3 : EMP **************************
			tot_emp=VectorStatistic(v_taz[3],"Sum",)
			WriteLine(MOE, "Total Employment,"+"\t"+r2s(tot_emp))
	
			// *************************** Step 4 : Trips/person **************************
			if n_dist=1 then Trips_Person= stat_array.QuickSum.Sum/POPSUM
			if n_dist<>1 then Trips_Person= stat_array.Temp.Sum/POPSUM
			WriteLine(MOE, "Trips Per Person,"+"\t"+r2s(Trips_Person))

			// *************************** Step 5 : Trips/person+emp **************************
			if n_dist=1 then Trips_PersonEMP= stat_array.QuickSum.Sum/(POPSUM+tot_emp)
			if n_dist<>1 then Trips_PersonEMP= stat_array.Temp.Sum/(POPSUM+tot_emp)
			WriteLine(MOE, "Trips Per Person + EMP,"+"\t"+r2s(Trips_PersonEMP))
	
			// *************************** Step 6 : Total VMT **************************
			//select links associate to the district
			SetLayer(llayer)
			
			if n_dist=1 then qry="Select * where [" + llayer +"].ID<>null"
			if n_dist<>1 then qry="Select * where DIST_NAME='"+moe_names[n_dist]+"'"
			n=SelectByQuery(moe_names[n_dist], "Several", qry,)
		
			/* 1,2,3,4
			VMT 5-12
			LOS 13-20
			PCt FF 21-28
			length 29
			MU vol 30-38
			lanemile 39
			
			MU VHT 40-47
			total mu vht 48
			
			*/
			
			v_rslt=GetDataVectors(net_rslt+"|"+moe_names[n_dist],{
				"CNT",		"VMT_TOT",	"VHT_TOT",	"SPD_VMT_SUM",
				"VMT_AMAB",
				"VMT_AMBA",
				"VMT_MDAB",
				"VMT_MDBA",
				"VMT_PMAB",
				"VMT_PMBA",
				"VMT_OPAB",
				"VMT_OPBA",
				
				"LOS_AMAB",
				"LOS_AMBA",
				"LOS_MDAB",
				"LOS_MDBA",
				"LOS_PMAB",
				"LOS_PMBA",
				"LOS_OPAB",
				"LOS_OPBA",
				
				"Pct_FF_AMAB",
				"Pct_FF_AMBA",
				"Pct_FF_MDAB",
				"Pct_FF_MDBA",
				"Pct_FF_PMAB",
				"Pct_FF_PMBA",
				"Pct_FF_OPAB",
				"Pct_FF_OPBA",
				
				"Leng",
				
				"VOL_MU",
				"VOL_MUAMAB",
				"VOL_MUAMBA",
				"VOL_MUMDAB",
				"VOL_MUMDBA",
				"VOL_MUPMAB",
				"VOL_MUPMBA",
				"VOL_MUOPAB",
				"VOL_MUOPBA",
				"LANEMILE",
				
				"MU_VHT_AMAB",
				"MU_VHT_AMBA",
				"MU_VHT_MDAB",
				"MU_VHT_MDBA",
				"MU_VHT_PMAB",
				"MU_VHT_PMBA",
				"MU_VHT_OPAB",
				"MU_VHT_OPBA",
				
				"MU_VHT_TOT"
			},)
			
			SetLayer(tazname)
			if n_dist=1 then qry="Select * where [" + tazname +"].ID<>null"
			if n_dist<>1 then qry="Select * where MOE_DIST"+i2s(n_dist_set)+"='"+moe_names[n_dist]+"'"
			n=SelectByQuery(moe_names[n_dist], "Several", qry,)
			
			VMTSUM=0
			for i=1 to v_rslt[2].length do
			VMTSUM=VMTSUM+nz(v_rslt[2][i])
			end
			
			WriteLine(MOE, "Total VMT,"+"\t"+r2s(VMTSUM))
			
			// *************************** Step 7 : VMT per Person **************************
			VMT_Person= VMTSUM/POPSUM
			WriteLine(MOE, "VMT Per Person,"+"\t"+r2s(VMT_Person))
			
			// *************************** Step 8 : VHT **************************
			
			VHTSUM=0
			for i=1 to v_rslt[3].length do
			VHTSUM=VHTSUM+nz(v_rslt[3][i])
			end
			
			WriteLine(MOE, "Total VHT," + "\t" +r2s(VHTSUM))
	
			// *************************** Step 9 : VHT Per person **************************

			VHT_Person= VHTSUM/POPSUM
			WriteLine(MOE, "VHT Per Person,"+"\t"+r2s(VHT_Person))
			
			
			// *************************** Step 10 : average vehicle speed=SPD_VMT_SUM/VMTSUM **************************
			
			SPD_VMT_SUM=0
			for i=1 to v_rslt[4].length do
			SPD_VMT_SUM=SPD_VMT_SUM+nz(v_rslt[4][i])
			end
			
			AVG_VEH_SPD=SPD_VMT_SUM/VMTSUM
		
			WriteLine(MOE, "Average Speed,"+"\t"+ r2s(AVG_VEH_SPD))
			
			// *************************** Step 11 : VMT at LOS F or worse(Congested) **************************
			VMT_LOSF=0
			for i=1 to v_rslt[5].length do	
				if v_rslt[13][i]="F" then VMT_LOSF=VMT_LOSF+v_rslt[5][i]
				if v_rslt[14][i]="F" then VMT_LOSF=VMT_LOSF+v_rslt[6][i]
				if v_rslt[15][i]="F" then VMT_LOSF=VMT_LOSF+v_rslt[7][i]
				if v_rslt[16][i]="F" then VMT_LOSF=VMT_LOSF+v_rslt[8][i]	
				if v_rslt[17][i]="F" then VMT_LOSF=VMT_LOSF+v_rslt[9][i]
				if v_rslt[18][i]="F" then VMT_LOSF=VMT_LOSF+v_rslt[10][i]
				if v_rslt[19][i]="F" then VMT_LOSF=VMT_LOSF+v_rslt[11][i]
				if v_rslt[20][i]="F" then VMT_LOSF=VMT_LOSF+v_rslt[12][i]	
			end
			
			WriteLine(MOE, "VMT at LOS F,	"+ r2s(VMT_LOSF))
			
			// *************************** Step 12 percent vmt over F **************************
	
			VMT_pct_LOSF=r2s(100*VMT_LOSF/VMTSUM)+"%"
			WriteLine(MOE, "Percent VMT at LOS F,"+"\t"+VMT_pct_LOSF)
			
			// *************************** Step 13 VMT with less than 0.7 pct_FF **************************
			VMT_70FF=0
			for i=1 to v_rslt[5].length do	
				if v_rslt[21][i]<0.7 then VMT_70FF=VMT_70FF+v_rslt[5][i]
				if v_rslt[22][i]<0.7 then VMT_70FF=VMT_70FF+v_rslt[6][i]
				if v_rslt[23][i]<0.7 then VMT_70FF=VMT_70FF+v_rslt[7][i]
				if v_rslt[24][i]<0.7 then VMT_70FF=VMT_70FF+v_rslt[8][i]	
				if v_rslt[25][i]<0.7 then VMT_70FF=VMT_70FF+v_rslt[9][i]
				if v_rslt[26][i]<0.7 then VMT_70FF=VMT_70FF+v_rslt[10][i]
				if v_rslt[27][i]<0.7 then VMT_70FF=VMT_70FF+v_rslt[11][i]
				if v_rslt[28][i]<0.7 then VMT_70FF=VMT_70FF+v_rslt[12][i]	
			end
			
			WriteLine(MOE, "VMT at less than 0.7FF,"+"\t" + r2s(VMT_70FF))
			
			// *************************** Step 14 Pct VMT at 0.7 pct_FF **************************
			
			VMT_pct_70FF=r2s(100*VMT_70FF/VMTSUM)+"%"
			WriteLine(MOE, "Percent VMT at 70pct FF,"+"\t"+VMT_pct_70FF)
			
			// *************************** Step 15 MU VMT **************************
			VMT_MU=0
			
			for i=1 to v_rslt[30].length do
				VMT_MU=VMT_MU+(nz(v_rslt[29][i])*nz(v_rslt[30][i]))
			end
			
			WriteLine(MOE, "MU VMT,"+"\t"+r2s(VMT_MU))
			
			// *************************** Step 16 MU VMT @ LOSF **************************
			VMT_MU_LOSF=0
			for i=1 to v_rslt[5].length do	
				if v_rslt[13][i]="F" then VMT_MU_LOSF=VMT_MU_LOSF+nz(v_rslt[29][i])*nz(v_rslt[31][i])
				if v_rslt[14][i]="F" then VMT_MU_LOSF=VMT_MU_LOSF+nz(v_rslt[29][i])*nz(v_rslt[32][i])
				if v_rslt[15][i]="F" then VMT_MU_LOSF=VMT_MU_LOSF+nz(v_rslt[29][i])*nz(v_rslt[33][i])
				if v_rslt[16][i]="F" then VMT_MU_LOSF=VMT_MU_LOSF+nz(v_rslt[29][i])*nz(v_rslt[34][i])
				if v_rslt[17][i]="F" then VMT_MU_LOSF=VMT_MU_LOSF+nz(v_rslt[29][i])*nz(v_rslt[35][i])
				if v_rslt[18][i]="F" then VMT_MU_LOSF=VMT_MU_LOSF+nz(v_rslt[29][i])*nz(v_rslt[36][i])
				if v_rslt[19][i]="F" then VMT_MU_LOSF=VMT_MU_LOSF+nz(v_rslt[29][i])*nz(v_rslt[37][i])
				if v_rslt[20][i]="F" then VMT_MU_LOSF=VMT_MU_LOSF+nz(v_rslt[29][i])*nz(v_rslt[38][i])
			end
			
			WriteLine(MOE, "MU VMT at LOS F,"+"\t"+r2s(VMT_MU_LOSF))
			
			// *************************** Step 17 Pct MU VMT @ LOSF **************************
			if (VMT_MU>0) then VMT_pct_MU_LOSF=r2s(100*VMT_MU_LOSF/VMT_MU)+"%"
            else VMT_pct_MU_LOSF=r2s(0)+"%"
			
			WriteLine(MOE, "Percent MU VMT at LOS F,"+"\t"+VMT_pct_MU_LOSF)
			
			// *************************** Step 18 MU VMT with less than 0.7 pct_FF **************************
			MUVMT_70FF=0
			for i=1 to v_rslt[5].length do	
				if v_rslt[21][i]<0.7 then MUVMT_70FF=MUVMT_70FF+nz((v_rslt[31][i]*v_rslt[29][i]))
				if v_rslt[22][i]<0.7 then MUVMT_70FF=MUVMT_70FF+nz((v_rslt[32][i]*v_rslt[29][i]))
				if v_rslt[23][i]<0.7 then MUVMT_70FF=MUVMT_70FF+nz((v_rslt[33][i]*v_rslt[29][i]))
				if v_rslt[24][i]<0.7 then MUVMT_70FF=MUVMT_70FF+nz((v_rslt[34][i]*v_rslt[29][i]))
				if v_rslt[25][i]<0.7 then MUVMT_70FF=MUVMT_70FF+nz((v_rslt[35][i]*v_rslt[29][i]))
				if v_rslt[26][i]<0.7 then MUVMT_70FF=MUVMT_70FF+nz((v_rslt[36][i]*v_rslt[29][i]))
				if v_rslt[27][i]<0.7 then MUVMT_70FF=MUVMT_70FF+nz((v_rslt[37][i]*v_rslt[29][i]))
				if v_rslt[28][i]<0.7 then MUVMT_70FF=MUVMT_70FF+nz((v_rslt[38][i]*v_rslt[29][i]))
			end
			
			WriteLine(MOE, "MU VMT at less than 0.7FF,"+"\t" + r2s(MUVMT_70FF))
			
			// *************************** Step 19 MU Pct VMT at 0.7 pct_FF **************************
			
			if (VMT_MU>0) then MUVMT_pct_70FF=r2s(100*MUVMT_70FF/VMT_MU)+"%"
            else MUVMT_pct_70FF=r2s(0)+"%"
            
			WriteLine(MOE, "Percent MU VMT at 70pct FF,"+"\t"+MUVMT_pct_70FF)
			
			// *************************** Step 18 MU VHT **************************
			VHT_MU=0
			
			for i=1 to v_rslt[48].length do
				VHT_MU=VHT_MU+nz(v_rslt[48][i])
			end
			
			WriteLine(MOE, "MU VHT,"+"\t"+r2s(VHT_MU))
			
			// *************************** Step 19 MU VHT @ LOSF **************************
			VHT_MU_LOSF=0
			for i=1 to v_rslt[5].length do	
				if v_rslt[13][i]="F" then VHT_MU_LOSF=VHT_MU_LOSF+nz(v_rslt[40][i])
				if v_rslt[14][i]="F" then VHT_MU_LOSF=VHT_MU_LOSF+nz(v_rslt[41][i])
				if v_rslt[15][i]="F" then VHT_MU_LOSF=VHT_MU_LOSF+nz(v_rslt[42][i])
				if v_rslt[16][i]="F" then VHT_MU_LOSF=VHT_MU_LOSF+nz(v_rslt[43][i])
				if v_rslt[17][i]="F" then VHT_MU_LOSF=VHT_MU_LOSF+nz(v_rslt[44][i])
				if v_rslt[18][i]="F" then VHT_MU_LOSF=VHT_MU_LOSF+nz(v_rslt[45][i])
				if v_rslt[19][i]="F" then VHT_MU_LOSF=VHT_MU_LOSF+nz(v_rslt[46][i])
				if v_rslt[20][i]="F" then VHT_MU_LOSF=VHT_MU_LOSF+nz(v_rslt[47][i])
			end
			WriteLine(MOE, "MU VHT at LOS F,"+"\t"+r2s(VHT_MU_LOSF))

			// *************************** Step 20 Pct MU VHT @ LOSF **************************
			
			if (VHT_MU>0) then VHT_pct_MU_LOSF=r2s(100*VHT_MU_LOSF/VHT_MU)+"%"
            else VHT_pct_MU_LOSF=r2s(0)+"%"
            
			WriteLine(MOE, "Percent MU VHT at LOS F,"+"\t"+VHT_pct_MU_LOSF)
			
			// *************************** Step 21 MU VHT @ 0.7FF **************************
			MUVHT_70FF=0
			for i=1 to v_rslt[5].length do	
				if v_rslt[21][i]<0.7 then MUVHT_70FF=MUVHT_70FF+nz(v_rslt[40][i])
				if v_rslt[22][i]<0.7 then MUVHT_70FF=MUVHT_70FF+nz(v_rslt[41][i])
				if v_rslt[23][i]<0.7 then MUVHT_70FF=MUVHT_70FF+nz(v_rslt[42][i])
				if v_rslt[24][i]<0.7 then MUVHT_70FF=MUVHT_70FF+nz(v_rslt[43][i])
				if v_rslt[25][i]<0.7 then MUVHT_70FF=MUVHT_70FF+nz(v_rslt[44][i])
				if v_rslt[26][i]<0.7 then MUVHT_70FF=MUVHT_70FF+nz(v_rslt[45][i])
				if v_rslt[27][i]<0.7 then MUVHT_70FF=MUVHT_70FF+nz(v_rslt[46][i])
				if v_rslt[28][i]<0.7 then MUVHT_70FF=MUVHT_70FF+nz(v_rslt[47][i])
			end
			
			WriteLine(MOE, "MU VHT at 0.7FF,"+"\t"+r2s(MUVHT_70FF))

			// *************************** Step 22 Pct MU VHT @ 0.7FF **************************
			
			if (VHT_MU>0) then VHT_pct_MU_70FF=r2s(100*MUVHT_70FF/VHT_MU)+"%"
            else VHT_pct_MU_70FF=r2s(0)+"%"
            
			WriteLine(MOE, "Percent MU VHT at 0.7FF,"+"\t"+VHT_pct_MU_70FF)
			
			// *************************** Step 23 Transit onboard **************************
            // for now - comment this out as network is not getting updated for ALLON and ALLOFF.
            
			transit_on=VectorStatistic(v_taz[1],"Sum",)
			WriteLine(MOE, "Total Transit Production,"+"\t"+r2s(transit_on))
			
			transit_off=VectorStatistic(v_taz[2],"Sum",)
			WriteLine(MOE, "Total Transit Attraction,"+"\t"+r2s(transit_off))
			
			transit_onbard=(transit_off+transit_on)/2
			WriteLine(MOE, "Total Transit onboard,"+"\t"+r2s(transit_onbard))
		
			// *************************** Step 24 LaneMile **************************
			SetLayer(llayer)
			
			if n_dist=1 then qry="Select * where [" + llayer +"].ID<>null and ccstyle<>99"
			if n_dist<>1 then qry="Select * where DIST_NAME='"+moe_names[n_dist]+"' and ccstyle<>99"
			n=SelectByQuery(moe_names[n_dist], "Several", qry,)

			v_lanemile=GetDataVectors(net_rslt+"|"+moe_names[n_dist],{"LANEMILE"},)
			
			Lanemile=0
			for i=1 to v_lanemile[1].length do
			Lanemile=Lanemile+nz(v_lanemile[1][i])
			end
			
			WriteLine(MOE, "LaneMile,"+"\t"+r2s(Lanemile))
			
		end
		
		mc0 :=mc0 //to reset the current core. 
		DropMatrixCore(pa_matrix, "QuickSum")
		DropMatrixCore(pa_matrix, "Temp")
		
	skip:	
	
	end
	CloseFile(MOE)
	CloseMap(temp_map)
	RunMacro("auto_validation") 
	ret_value=1
	quit:	
	return(ret_value)
	
endMacro 

Macro "auto_validation"
	shared Scen_Dir
	
    folder = Scen_Dir + "reports\\validation\\automation"
    path_info = SplitPath(folder)
	drive = path_info[1]

    command_line =  "cmd /c " + drive + "&& cd " + folder + " && auto_validation.bat"
    status = RunProgram(command_line,{{"Maximize", "True"}})

endMacro

/*
1. Create a new report file (moe2.bin)
2. open the MOE.csv
3. reads the district name field from the MOE.csv
4. look for "*" to get number of fields in the MOE report
5. create the table with the following format
district, 	district name,	field1(trips),			field2(pop)
1_0				regional			10569485			2625021
1_1				CBD					..
..
etc


*/
macro "MOE2" (Args) //MOE 2 for the MAP
	RunMacro("TCB Init")
	
	
	shared Scen_Dir
	//create an MOE file
	MOE_file = Scen_Dir + "reports\\moe\\scenario_moe.csv"
	MOE = OpenFile(MOE_file,"w")
		
		
		
	ret_value=1
	quit:	
	return(ret_value)
endMacro


Macro "Build Daily Trip Table" (daily_matrix_file, Args)
	shared Scen_Dir
	
	periods = {"AM","MD","PM","OP"}

	// Assignment trip Tables by time period
	OD = {Args.[AM OD Matrix], Args.[MD OD Matrix], Args.[PM OD Matrix], Args.[OP OD Matrix]}

	am_od_matrix = OpenMatrix(Args.[AM OD Matrix],)
	pm_od_matrix = OpenMatrix(Args.[PM OD Matrix],)
	md_od_matrix = OpenMatrix(Args.[MD OD Matrix],)
	op_od_matrix = OpenMatrix(Args.[OP OD Matrix],)
	allod={am_od_matrix,md_od_matrix,pm_od_matrix,op_od_matrix}
	
	//daily_matrix_file = Scen_Dir + "outputs\\DAILYOD.mtx"
	CopyFile(OD[1], daily_matrix_file)
	
	daily_matrix = OpenMatrix(daily_matrix_file,)
	matrix_cores = GetMatrixCoreNames(daily_matrix)
	
	//set all cores to 0
	RunMacro("TCB Init")
	for core=1 to matrix_cores.Length do
		mc_daily = RunMacro("TCB Create Matrix Currency", daily_matrix_file, matrix_cores[core], "Rows", "Cols")
		mc_daily := 0
	end
	
	//add all time periods
	// matrix_cores = {"Passenger", "Commercial", "SingleUnit", "MU", "Preload_EIMU", "Preload_IEMU", "Preload_EEMU","Preload_IESU","Preload_EESU","Preload_Pass","HOV","HOV2","HOV3"}
	matrix_cores = {"IICOM", "IISU", "IIMU", "IEAUTO", "IESU", "EEAUTO", "EESU", "Passenger_SOV", "Passenger_HOV2", "Passenger_HOV3", "Preload_MU", "Preload_SU", "PersonTrips", "IEMU", "EIMU", "EEMU", "Passenger", "Commercial", "SingleUnit", "MU", "Preload_EIMU", "Preload_IEMU", "Preload_EEMU", "Preload_IESU", "Preload_EESU", "Preload_Pass", "HOV", "HOV2", "HOV3", "Autos"}
	for p=1 to periods.length do
		for core=1 to matrix_cores.Length do
			mc_daily = RunMacro("TCB Create Matrix Currency", daily_matrix_file, matrix_cores[core], "Rows", "Cols")
			mc_period = RunMacro("TCB Create Matrix Currency", OD[p], matrix_cores[core], "Rows", "Cols")
			mc_daily := nz(mc_daily) + nz(mc_period)
		end	
	end
	
	mc_daily = null
	mc_perio = null

endMacro



Macro "HwycadLog"(arr)
  shared Scen_Dir
  
  fprlog=null
  log1=arr[1]
  log2=arr[2]
  dif2=GetDirectoryInfo(Scen_Dir+"\\hwycadx.log","file")
  if dif2.length>0 then fprlog=OpenFile(Scen_Dir+"\\hwycadx.log","a") 
  else do 
	fprlog=OpenFile(Scen_Dir+"\\hwycadx.log","w")
  end
  mytime=GetDateAndTime()  
  if log2=null then writeline(fprlog,mytime+", "+log1)
  else writeline(fprlog,mytime+", "+log1+", "+log2)
  CloseFile(fprlog)
  fprlog = null
  return()
endMacro

Macro "RuntimeLog"(arr)
  shared Scen_Dir
  
  fprlog=null
  
  log1=arr[1]
  starttime=arr[2]
  
  dif2=GetDirectoryInfo(Scen_Dir+"\\runtime.log","file")
  if dif2.length>0 then fprlog=OpenFile(Scen_Dir+"\\runtime.log","a") 
  else do 
	fprlog=OpenFile(Scen_Dir+"\\runtime.log","w")
  end
  
  mytime=GetDateAndTime()  
  
  if starttime <> null then do
	{sDay, sMonth, sDate, sTime, sYear} = ParseString(starttime, " ")
	{eDay, eMonth, eDate, eTime, eYear} = ParseString(mytime, " ")
	
	{sH, sM, sS} = ParseString(sTime, ":")
	{eH, eM, eS} = ParseString(eTime, ":")
	
	if (CompareArrays({sMonth, sYear}, {eMonth, eYear},)) then do
		start_min = 1440 * StringToInt(sDate) + 60 * StringToInt(sH) + StringToInt(sM)
		end_min =1440 * StringToInt(eDate) + 60 * StringToInt(eH) + StringToInt(eM)
	end
	else do
		//assuming that model wouldn't take multiple days to finish
		start_min = 60 * StringToInt(sH) + StringToInt(sM)
		end_min = 1440 + 60 * StringToInt(eH) + StringToInt(eM)
	end
	
	elapsed = end_min - start_min
  
	writeline(fprlog,mytime+", Finished "+log1+" in " + i2s(elapsed) + " mins")
  end
  //else writeline(fprlog, mytime+", Started "+log1)
  
  CloseFile(fprlog)
  fprlog = null
  
  Return(mytime)
  
endMacro

 
