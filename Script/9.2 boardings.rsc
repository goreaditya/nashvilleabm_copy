Macro "Stop_Summary" (Args)

	shared Scen_Dir
	
	starttime = RunMacro("RuntimeLog", {"Transit Stop Summary ", null})
	RunMacro("HwycadLog", {"9.2 boardings.rsc", "  ****** Tranist Stop Summary ****** "})

   // Inputs
	net_file = Args.[hwy db]                  // highway network
	route_file = Args.rs_file           // transit network
   
   // Outputs
   OutDir = Scen_Dir +"\\outputs"
	all_boards_file = Args.[Transit Boarding]
	all_boards_tmp_file=Scen_Dir +"\\outputs\\temp_stops.bin"
	
	//boarding file
	all_boards_info = {
		{"Route_ID", "Integer", 8, null, "Yes"},
		{"Route_Name", "String", 25, null, "Yes"},
		{"STOP_ID", "Integer", 8, null, "No"},
		
		{"NODE_ID", "Integer", 8, null, "No"},
		
		{"ON", "Real", 10, 2, "No"},
		{"OFF", "Real", 10, 2, "No"}
	}

	
	
	all_boards_name = "ALL_BOARDINGS"
	
	//temp boarding file
	all_boards_tmp = CreateTable ("all_boards_tmp", all_boards_tmp_file, "FFB", all_boards_info)


	
// ----- Set the paths for the TASN_FLOW files
	Modes            = {"Local","Brt","ExpBus","UrbRail","ComRail"}      // List of transit modes
    AccessAssgnModes = {"Walk","PnR","KnR"}                              // List of access modes for mode choice model
    Periods = {"AM","MD","PM","OP"}

	v_stop=null
	v_route=null
	v_on=null
	v_off=null
	
	//open the on-off tables to get boardings by stop
	Dim path_ONOS[Periods.length,Modes.length,AccessAssgnModes.length]
	for i = 1 to Periods.length do
		for j = 1 to Modes.length do
			for k = 1 to AccessAssgnModes.length do
				path_ONOS[i][j][k] = OutDir + "\\" + Periods[i] + AccessAssgnModes[k] + Modes[j] + "OnOffFlow.bin"
				tablename=Periods[i]+"_"+Modes[j]+"_"+AccessAssgnModes[k]
				OpenTable(tablename,"FFB",{path_ONOS[i][j][k],})
				v_temp=GetDataVectors(tablename+"|",{"ROUTE","STOP","ON","OFF"},{{"Sort Order", {{"ROUTE", "Ascending"}}}})
				
				//create a new vecotr for the temp
				dim v_temp2[v_temp[1].length]
				
				for m=1 to v_temp[1].length do
					v_temp2[m]={v_temp[1][m],v_temp[2][m],v_temp[3][m],v_temp[4][m]}
				end
				
				AddRecords(all_boards_tmp,{"Route_ID", "STOP_ID", "ON","OFF"}, v_temp2, null)

			end
		end
	end

	
	process:
	//open table, formula route+stops, aggregate
	tmp_tablename=OpenTable("tmp","FFB",{all_boards_tmp_file,})
	
	//view=GetView()
	//create a formula for routeID+ StopID
	CreateExpression(tmp_tablename,"Route-Stop","i2s(Route_ID)+'-'+i2s(Stop_ID)",)

	//aggregate
	rslt = AggregateTable("Final",tmp_tablename+"|", "FFB",  all_boards_file, "Route-Stop", {
		{"On","SUM", }, {"OFF","SUM",}
		
		}, null)

	//get table structure and modify
	strct = GetTableStructure("Final")
	
	//modify table
	for i = 1 to strct.length do
		// Copy the current name to the end of strct
		strct[i] = strct[i] + {strct[i][1]}
	end
	
	// Add a field for 2002 Sales data
	strct = strct + {
		{"Route_ID", "Integer", 10, null, "True", , , , , , , null},
		{"Route_Name", "String", 20, null, "True", , , , , , , null},
		{"Stop_ID", "Integer", 10, null, "True", , , , , , , null},
		{"Node_ID", "Integer", 10, null, "True", , , , , , , null}
		}

	// Modify the table
	ModifyTable("Final", strct)


	//read the route-stop field, and split
	v=GetDataVector("Final|","Route-Stop",)
	
	a1=null
	a2=null
	
	for i=1 to v.length do
		pieces=ParseString(v[i], "-")
		a1=a1+{s2i(pieces[1])}
		a2=a2+{s2i(pieces[2])}
	end
	
	v1=ArrayToVector(a1)
	v2=ArrayToVector(a2)
	
	SetDataVector("Final|", "Route_ID", v1, )
	SetDataVector("Final|", "Stop_ID", v2, )
	
	//get stop table name
	pieces=ParseString(Args.rs_file,".")
	rts_stop=pieces[1]+"S.bin"
	
	//fill node id
	 Opts = null
    Opts.Input.[Dataview Set] = {{all_boards_file, rts_stop, {"Stop_ID"}, {"STOP_ID"}}, "Final+RouteS"}
    Opts.Global.Fields = {"Node_ID"}
    Opts.Global.Method = "Formula"
    Opts.Global.Parameter = "NearNode"
    ret_value = RunMacro("TCB Run Operation", "Fill Dataview", Opts, &Ret)
	if !ret_value then goto quit
	
	
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
	
	
	//reads taz ID
	v_ID=GetDataVector(tazname+"|", "ID", ) 
	
	//join node and all boarding table
	aggr = {{"ON", {{"Sum"}}},{"OFF", {{"Sum"}}} }
	join_vw = JoinViews("jv", nlayer+".ID", "Final.Node_ID", {{"A", }, {"Fields", aggr}})
	
	//aggregate by TAZ ID in the node layer
	//v1=ID, v2=on, v3=off
	
	dim a_final[2,v_ID.length]
	
	v_temp=null
	SetView(nlayer)
	currentview=GetView()
	
	for i=1 to v_ID.length do
		qry="Select * where TAZID_STOP_New="+i2s(v_ID[i])
		n = SelectByQuery ("selection", "Several", qry,)
		if n>0 then do 
			v_temp=GetDataVectors(join_vw+"|selection",{"ON","OFF"},)
			a_final[1][i] = VectorStatistic(v_temp[1], "Sum", )
			a_final[2][i] = VectorStatistic(v_temp[2], "Sum", )
		end
	end
	
	v_on=ArrayToVector(a_final[1])
	v_off=ArrayToVector(a_final[2])
	
	//setdatavector to the TAZ ID for on and OFF
	SetDataVectors(tazname+"|", {{"ALLON", v_on},{"ALLOFF",v_off}},)
	endtime = RunMacro("RuntimeLog", {"Transit Stop Summary ", starttime})
	ret_value=1
quit:
	CloseMap(temp_map)
	return(ret_value)
	

endMacro