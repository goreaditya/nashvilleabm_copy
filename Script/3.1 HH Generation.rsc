
//**************************************/
//*      					Part 2  					   	        */
//*					Trip Generation							 */
//**************************************/

macro "Trip Generation1" (Args)    // Trip Generation for households

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
	
	// ************************household production -production.bin - table 1
	generation1: 
	UpdateProgressBar("household production -production.bin", )
	OpenTable("production","FFB",{Args.[HHGenration],})
	v_production=GetDataVectors("production|",{"TRIP","Var1","Var2","Var3","Var4","Coeff1","Coeff2","Coeff3","Coeff4"},)
	
	//read purpose names purpose names
	purnames={v_production[1][1]} //eg: HBW1
	
	for i=2 to v_production[1].length do //reads the records, if the purpose name <> previous then put the name in the arry
		if v_production[1][i]<>v_production[1][i-1] then purnames=purnames+{v_production[1][i]}
	end
	
	//combine fields to get the formula
	for i=1 to 4 do
		a="temp"+i2s(i)
		b="if Coeff"+i2s(i)+" <> null then "+	 "Var"+i2s(i)+"+'*'+" +"Coeff"	+i2s(i)			//if coeff1 <>null then Var1+"*"+Coeff1
		CreateExpression("production",a,b,)
	end
	
	//get the combined formula fields
	v_production=GetDataVectors("production|",{"TRIP","temp1","temp2","temp3","temp4"},)
	
	//applying cross table rates to the TAZ file
	counter=1 //used to assign unique name for all different trip purposes
	
	for p=1 to v_production[1].length do  // all trip purposes
		a= v_production[1][p]+"_"+i2s(counter) //eg:HBW1_1. represents W0V1 Cell formula field
		b= "nz("+v_production[2][p]+")"
		if b= "nz()" then b="0"
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a=v_production[1][p]+"_"+i2s(counter) //eg:HBW1_2
		b= "nz("+v_production[3][p]+")"
		if b= "nz()" then b="0"
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		a=v_production[1][p]+"_"+i2s(counter) //eg:HBW1_3
		b= "nz("+v_production[4][p]+")"
		if b= "nz()" then b="0"
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1

		a= v_production[1][p]+"_"+i2s(counter)  //eg:HBW1_4
		b= "nz("+v_production[5][p] +")"
		if b= "nz()" then b="0" 
		CreateExpression(tazname,a,b,{{"Type","Real"}})
		counter=counter+1
		
		//if the next record is differnt purpose then reset the counter
		if p<>v_production[1].length then do 
			if v_production[1][p]<>v_production[1][p+1] then do
				counter=1
			end
		end
		if p=v_production[1].length then allnames=allnames+{v_production[1][p]} //last purpose name	
	end
	
	//Sum All the trips in different cross table cells in the TAZ file
	for p=1 to purnames.length do	
	
		allformula=purnames[p]+"_"+i2s(1) //first record
		for i=2 to 16 do //cross tables for each purpose are 4x4
			allformula=allformula +"+"+purnames[p]+"_"+i2s(i)
		end
		
		a=purnames[p]
		b=allformula
		CreateExpression(tazname,a,b,{{"Type","Real"}})	
		
		purposefields1=purposefields1+{{a}+fieldformats} //********reads field name for production table
		table1_names=table1_names+{a}//reads the field names for the household production table
	end
	
	// *****************************generation5: create household production table*********************** //
	UpdateProgressBar("create the household production table", )
	generation5: //create household production table
	
	production_table=Args.[Household Production]

	//get the TAZ ID
	SetView(nlayer)
	qry="Select * where CCSTYLE=99"
	n=SelectByQuery("TAZ", "Several", qry,)
	v_ID_TAZ=GetDataVector(nlayer+"|TAZ","ID",{{"Sort Order",{{"ID","Ascending"}}}})
	
	//get the external station ID
	qry="Select * where CCSTYLE=98 or CCSTYLE=97"
	n=SelectByQuery("External", "Several", qry,)
	v_ID_external=GetDataVector(nlayer+"|External","ID",{{"Sort Order",{{"ID","Ascending"}}}})
	
	//Reads and Writes the IDs
	CreateTable("Household Production", production_table, "FFB", purposefields1)
	AddRecords("Household Production", null, null, {{"Empty Records", v_ID_TAZ.length}})
	SetDataVector("Household Production|", "ID", v_ID_TAZ, )
	percentage=5 //progress bar percentage
	
	for i=1 to table1_names.length do //reads the production values(formulated fields) stored in TAZ file
		UpdateProgressBar("create the household production table", percentage)
		v_temp=GetDataVector(tazname+"|",table1_names[i],{{"Sort Order",{{"ID_NEW","Ascending"}}}})
		v_temp=nz(v_temp)
		SetDataVector("Household Production|", table1_names[i], v_temp, )
		percentage=r2i(percentage+2)
	end
	
	//add external station IDs so the matrix will be 2900x2900
	AddRecords("Household Production", null, null, {{"Empty Records", v_ID_external.length}})
	SetView("Household Production")
	SelectByQuery("External", "Several", "Select * where  ID=null",)
	SetDataVector("Household Production|External", "ID",v_ID_external, )
	
    ret_value = 1
    quit:
    if !ret_value then showmessage("Error in "+err)
    CloseMap("temp")
    return(ret_value)
    
endmacro	