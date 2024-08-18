macro "Trip Generation2" (Args)    // Trip Generation

	shared prj_dry_run, Scen_Dir
    if prj_dry_run then return(1)

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
	temp_layer =AddLayer(temp_map,tazname,taz_db,tazname)
	SetView(tazname)
	
	purposefields1={{"ID", "Integer", 9, null, "No"}} //ID field format
	fieldformats={"Real",9,2,"No"} //other fields' format
	

	// *****************************generation2: non-household production/attraction -attraction.bin, production=attraction - table 2*********************** //
	generation2: 
	UpdateProgressBar("non-household production/attraction", )
	purposefields2={{"ID", "Integer", 9, null, "No"}} //ID field
    purposefields3={{"ID_OLD", "Integer", 9, null, "No"}} //ID field
	
	OpenTable("attraction","FFB",{Args.[NONHHGeneration],})
	v_attraction=GetDataVectors("attraction|",{"TRIP","Var1","Var2","Var3","Var4","Var5","Var6","Coeff1","Coeff2","Coeff3","Coeff4","Coeff5","Coeff6"},)

	//purpose names for all II non-HH trips
	purnames=v_attraction[1]
	
	//combine fields to get the formula
	for i=1 to 6 do
		a="temp"+i2s(i)
		b="if Coeff"+i2s(i)+" <> null then "+	 "Var"+i2s(i)+"+'*'+" +"Coeff"	+i2s(i)			//if coeff1 <>null then Var1+"*"+Coeff1
		CreateExpression("attraction",a,b,)
	end
	
	v_attraction=GetDataVectors("attraction|",{"TRIP","temp1","temp2","temp3","temp4","temp5","temp6"},)
	
	//formulate
	counter=1
	for p=1 to v_attraction[1].length do  
		a= v_attraction[1][p]+"_"+i2s(counter)
		b= "nz("+v_attraction[2][p]+")"
		if b= "nz()" then b="0"
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a=v_attraction[1][p]+"_"+i2s(counter)
		b= "nz("+v_attraction[3][p]+")"
		if b= "nz()" then b="0"
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a=v_attraction[1][p]+"_"+i2s(counter)
		b= "nz("+v_attraction[4][p]+")"
		if b= "nz()" then b="0"
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a= v_attraction[1][p]+"_"+i2s(counter) 
		b= "nz("+v_attraction[5][p] +")"
		if b= "nz()" then b="0" 
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a= v_attraction[1][p]+"_"+i2s(counter) 
		b= "nz("+v_attraction[6][p] +")"
		if b= "nz()" then b="0" 
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a= v_attraction[1][p]+"_"+i2s(counter) 
		b= "nz("+v_attraction[7][p] +")"
		if b= "nz()" then b="0" 
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		if p<>v_attraction[1].length then do
			if v_attraction[1][p]<>v_attraction[1][p+1] then counter=1
		end
	end

	for p=1 to purnames.length do //number of purposes
		allformula=purnames[p]+"_"+i2s(1)
		for i=2 to 6 do //5 variables and formula
			allformula=allformula +"+"+purnames[p]+"_"+i2s(i)
		end
		
		a=purnames[p]
		b=allformula
		
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		purposefields2=purposefields2+{{a+"_P"}+fieldformats} //********reads field name for unbalanced PA table - production
		purposefields2=purposefields2+{{a+"_A"}+fieldformats} //********reads field name for unbalanced PA table - attraction
		table2_names=table2_names +{a} //reads the field names for the non-household PA table table
	end
	
// *****************************generation3: external station attraction - table 3*********************** //
	generation3: 
	UpdateProgressBar("External Stations", )
	

	OpenTable("externals","FFB",{Args.[Externals],})
	v_externals=GetDataVectors("externals|",{"TRIP","Var1","Var2","Var3","Var4","Var5","Var6","Coeff1","Coeff2","Coeff3","Coeff4","Coeff5","Coeff6"},)
	
	//purpose names
	purnames=v_externals[1]
	
	//combine fields to get the formula(in the external rate table)
	for i=1 to 6 do
		a="temp"+i2s(i)
		b="if Coeff"+i2s(i)+" <> null then "+	 "Var"+i2s(i)+"+'*'+" +"Coeff"	+i2s(i)			//if coeff1 <>null then Var1+"*"+Coeff1
		CreateExpression("externals",a,b,)
	end
	v_externals=GetDataVectors("externals|",{"TRIP","temp1","temp2","temp3","temp4","temp5","temp6"},)
	
	//formulate(in the taz)
	counter=1
	for p=1 to purnames.length do  //
		a= purnames[p]+"_"+i2s(counter)
		b= "nz("+v_externals[2][p]+")"
		if b= "nz()" then b="0"
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a=purnames[p]+"_"+i2s(counter)
		b= "nz("+v_externals[3][p]+")"
		if b= "nz()" then b="0"
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a=purnames[p]+"_"+i2s(counter)
		b= "nz("+v_externals[4][p]+")"
		if b= "nz()" then b="0"
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a= purnames[p]+"_"+i2s(counter) 
		b= "nz("+v_externals[5][p] +")"
		if b= "nz()" then b="0" 
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a= purnames[p]+"_"+i2s(counter) 
		b= "nz("+v_externals[6][p] +")"
		if b= "nz()" then b="0" 
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a= purnames[p]+"_"+i2s(counter) 
		b= "nz("+v_externals[7][p] +")"
		if b= "nz()" then b="0" 
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		if p<>purnames.length then do
			if purnames[p]<>purnames[p+1] then counter=1
		end
	end
	
	for p=1 to purnames.length do 
		allformula=purnames[p]+"_"+i2s(1) //first record
		
		for i=2 to 6 do //5 variables and formula
			allformula=allformula +"+"+purnames[p]+"_"+i2s(i)
		end
		
		a=purnames[p]
		b=allformula
		CreateExpression(tazname,a,b,{{"Type","Real"}})		
	end



// *****************************generation4: Reads The External Nodes - table 3*********************** //
	generation4: 
	UpdateProgressBar("Reads The External Trip Productions", )
	
	//get the external station ID
	SetView(nlayer)
	qry="Select * where CCSTYLE=97 or CCSTYLE=98"
	n=SelectByQuery("Externals", "Several", qry,)
	
	vehicles={"AUTO","SU"} //no MU, it's being taken care of in the freight model
	
	if n=null or n=0 then do 
		err=" no external station selected"
		goto quit
	end
	
	for v=1 to vehicles.length do
		//fill VEH AADT by Type
		Opts = null
		Opts.Input.[Dataview Set] = {hwy_db+"|"+nlayer, nlayer, "Externals", }
		Opts.Global.Fields = {vehicles[v]}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = "R2I(AADT* VHCL_"+vehicles[v]+"/100)" // calculate the number of vehicles using vehicle percent
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	
		//fill EE VEH AADT by Vehicle type
		Opts = null
		Opts.Input.[Dataview Set] = {hwy_db+"|"+nlayer, nlayer, "Externals", }
		Opts.Global.Fields = {"EE"+vehicles[v]}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = "R2I(EEPCT_"+vehicles[v]+"*"+vehicles[v]+"/200)"  
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	
		//fill IE VEH AADT by Vehicle type
		Opts = null
		Opts.Input.[Dataview Set] = {hwy_db+"|"+nlayer, nlayer, "Externals", }
		Opts.Global.Fields = {"IE"+vehicles[v]}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = vehicles[v]+"-"+"2*EE"+vehicles[v]
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	end
	
	purnames={"IEAUTO","IESU","EEAUTO","EESU"} 
	table4_names=purnames
	
	for p=1 to purnames.length do 
			purposefields4=purposefields4+{{purnames[p]+"_P"}+fieldformats} //********reads field name for unbalanced PA table
			purposefields4=purposefields4+{{purnames[p]+"_A"}+fieldformats} //********reads field name for unbalanced PA table
	end
	
	
	// *****************************generation6: create the non-household PA table*********************** //
	generation6: //create the non-household Unbal PA table
	UpdateProgressBar("create the non-household PA table", r2i(percentage))
	
	//get the TAZ ID
	SetView(nlayer)
	qry="Select * where CCSTYLE=99"
	n=SelectByQuery("TAZ", "Several", qry,)
	v_ID_TAZ=GetDataVector(nlayer+"|TAZ","ID",{{"Sort Order",{{"ID","Ascending"}}}})
    v_ID_TAZ_OLD=GetDataVector(nlayer+"|TAZ","TAZID",{{"Sort Order",{{"ID","Ascending"}}}})
	
	//get the external station ID
	qry="Select * where CCSTYLE=98 or CCSTYLE=97"
	n=SelectByQuery("External", "Several", qry,)
	v_ID_external=GetDataVector(nlayer+"|External","ID",{{"Sort Order",{{"ID","Ascending"}}}})
    v_ID_external_old=GetDataVector(nlayer+"|External","TAZID",{{"Sort Order",{{"ID","Ascending"}}}})
	
	//production_table=Args.[Non-Household PA]
	unbal=Scen_Dir + "outputs\\unbal.bin"
	
	//Reads and Writes the IDs
	CreateTable("Unbalanced", unbal, "FFB", purposefields2+purposefields3+purposefields4) //non-household PA, external attraction, external production
	AddRecords("Unbalanced", null, null, {{"Empty Records", v_ID_TAZ.length}})
	SetDataVector("Unbalanced|", "ID", v_ID_TAZ, )
    SetDataVector("Unbalanced|", "ID_OLD", v_ID_TAZ_OLD, )
	
	UpdateProgressBar("create the non-household PA table", r2i(percentage))
	
	
	//table 2, P=A
	for i=1 to table2_names.length do //reads non-household PA from TAZ table
		v_temp=GetDataVector(tazname+"|",table2_names[i],{{"Sort Order",{{"ID_NEW","Ascending"}}}}) //ID_NEW?
		v_temp=nz(v_temp)
		SetDataVector("Unbalanced|", table2_names[i]+"_P", v_temp, )
		SetDataVector("Unbalanced|", table2_names[i]+"_A", v_temp, )
		UpdateProgressBar("create the non-household PA table", r2i(percentage))
		percentage=percentage+1.5
	end
	
	//table 3, external attraction from TAZ layer
	vehicles={"AUTO","SU"}
	for i=1 to vehicles.length do 
		v_temp=GetDataVector(tazname+"|","IE"+vehicles[i],{{"Sort Order",{{"ID_NEW","Ascending"}}}}) //ID_NEW?
		v_temp=nz(v_temp)
		SetDataVector("Unbalanced|", "IE"+vehicles[i]+"_A", v_temp, )
	end
	
	//table 4, external production from node layer
	//add records for external ID
	AddRecords("Unbalanced", null, null, {{"Empty Records", v_ID_external.length}})
	
	SetView("Unbalanced")
	qry="Select * where ID=null"
	n=SelectByQuery("External", "Several", qry,)
	
	//write the external station ID to the unbalanced table
	SetDataVector("Unbalanced|External", "ID", v_ID_external, )
    SetDataVector("Unbalanced|External", "ID_OLD", v_ID_external_old, )
	
	directions={"IE","EE"}
	for d=1 to directions.length do
		for i=1 to vehicles.length do
			UpdateProgressBar("create the non-household PA table", r2i(percentage))
			percentage=percentage+1

			//IE, only reads P
			if directions[d]="IE" then do
				//external station production
				v_temp=GetDataVector(nlayer+"|External",directions[d]+vehicles[i],{{"Sort Order",{{"ID","Ascending"}}}})
				v_temp=nz(v_temp)
				SetDataVector("Unbalanced|External", directions[d]+vehicles[i]+"_P", v_temp, )
			end
			
			//EE, reads both P and A 
			if directions[d]="EE" then do
				v_temp=GetDataVector(nlayer+"|Externals",directions[d]+vehicles[i],{{"Sort Order",{{"ID","Ascending"}}}})
				v_temp=nz(v_temp)
				SetDataVector("Unbalanced|External", directions[d]+vehicles[i]+"_P", v_temp, )
				SetDataVector("Unbalanced|External", directions[d]+vehicles[i]+"_A", v_temp, )
			end	
		end
	end
	
	// *****************************generation6: balance the non-household trips*********************** //
	
	generation7: //create the non-household Unbal PA table
	UpdateProgressBar("balance the non-household trips", r2i(percentage))
	balanced_table=Args.[Non-Household PA]
	
	names=table2_names + table4_names 
	dim allnames_p[names.length]
	dim allnames_a[names.length]
	dim holds[names.length]
	
	for i=1 to names.length do
		allnames_p[i]=names[i]+"_P"
		allnames_a[i]=names[i]+"_A"
		holds[i]="Hold Vector 1"
	end
	
	OpenTable("Unbalanced","FFB",{unbal,})
	
	//nz all the numbers in the unbal file
	for i=1 to names.length do
		Opts = null
		Opts.Input.[Dataview Set] = {unbal, "Unbalanced"}
		Opts.Global.Method = "Formula"
		
		Opts.Global.Fields = {allnames_p[i]}
		Opts.Global.Parameter = "nz("+allnames_p[i]+")"
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		
		Opts.Global.Fields = {allnames_a[i]}
		Opts.Global.Parameter = "nz("+allnames_a[i]+")"
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	end
	
    // add old tazid to the table - not needed yet
    
	Adj=Args.[County Adj]
	OpenTable("County Adj","FFB",{Adj,})
	
	a="county"
	b='if left(i2s(id_old),2)="37" then "37" else left(i2s(id_old),3)'
	CreateExpression("Unbalanced",a,b,)

	a={"IICOM_P","IICOM_A","IISU_P","IISU_A","IIMU_P","IIMU_A","IESU_A"}
	b={"COM","COM","SU","SU","MU","MU","SU"}
	for i=1 to a.length do
		Opts = null
		Opts.Input.[Dataview Set] = {{unbal, Adj, {"county"}, {"County"}}, "Unbalanced+Non-Household Adi"}
		Opts.Global.Fields = {a[i]}
		Opts.Global.Method = "Formula"
		Opts.Global.Parameter = a[i]+"*"+b[i]
		ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
		if !ret_value then goto quit
	end
	
	
	RunMacro("TCB Init")
    Opts = null
    Opts.Input.[Data View Set] = {unbal, "Unbalanced"}
    Opts.Field.[Vector 1] = allnames_p
    Opts.Field.[Vector 2] = allnames_a
    Opts.Global.[Holding Method] = holds
    Opts.Global.[Store Type] = "Real"
    Opts.Output.[Output Table] = balanced_table

	ret_value = RunMacro("TCB Run Procedure", "Balance", Opts, &Ret)
	err="Trip Balancing"
	if !ret_value then goto quit
	
    ret_value = 1
    quit:
    if !ret_value then showmessage("Error in "+err)
    CloseMap("temp")
    return(ret_value)
    
endmacro	