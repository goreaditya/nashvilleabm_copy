
/*
Adjust base year Ext trips for a future year
nagendra.dhakar@rsginc.com
Nashville ABM Update 2017
*/

Macro "Run"
	shared periods, input_dir
	shared zones_internal, zones_external
	shared final_outmatrix
	shared summary_outfile

	//Set settings
	RunMacro("Settings")
	
	//Get internal zones
	RunMacro("Get Model Zones")
	file_writer = RunMacro("Start a File Writer", summary_outfile)
	
	RunMacro("Compute Matrix Statistics", "Base Year Nashville Trips", file_writer, input_dir, final_outmatrix, periods, "_")
		
	//Adjust trips
	RunMacro("Adjust Trips")
	RunMacro("Compute Matrix Statistics", "Adjusted Nashville Trips", file_writer, input_dir, final_outmatrix, periods, "_Scaled")	
		
	CloseFile(file_writer)

endMacro

Macro "Settings"
	shared periods, classes, trip_types
	shared tazindex_file, final_outmatrix
	shared summary_outfile, input_dir
	
	//path settings	
	scen_dir = "E:\\Projects\\Clients\\Nashville\\Model\\BaseYear\\Calibration\\ABM_TCAD8_TAZSPLIT\\2018\\"
	input_dir = scen_dir + "inputs\\" //requires to have SU_AdjFactor.bin or MU_AdjFactor.bin or AUTO_AdjFactor.bin
	tazindex_file = scen_dir + "DaySim\\inputs\\nashville_taz_index_2017.csv"
	final_outmatrix = "Nashville_ExtAutos" //name of the file without extension
	summary_outfile = input_dir + "summary_auto.csv"

	periods = {"AM", "MD", "PM", "OP"}
	trip_types = {"IE", "EI", "EE"}
	classes = {"AUTO"}

endMacro

Macro "Compute Matrix Statistics" (trip_type, fptr, outdir, mat_name, periods, separator)
		
	for p=1 to periods.length do
		mat_file = outdir + mat_name + separator + periods[p] + ".mtx"		
		mat = OpenMatrix(mat_file,)
		
		stat_array = MatrixStatistics(mat,)
		
		for core=1 to stat_array.length do
			stats = stat_array[core]
			out_string = trip_type + "," + periods[p] + "," + stats[1]
			for stat = 1 to stats[2].length do
				summary = stats[2][stat]
				out_string = out_string + "," + RealToString(summary[2])		
			end
			WriteLine(fptr, out_string)
		end
	
	end

endMacro

Macro "Adjust Trips"
	shared input_dir
	shared periods, classes, final_outmatrix
	shared tazindex_file, trip_types
	
	// Adjust matrices
	for p=1 to periods.length do
		in_mat = input_dir + final_outmatrix + "_" + periods[p] + ".mtx"
		out_mat = input_dir + final_outmatrix + "_Scaled" + periods[p] + ".mtx"
		
		//Run Adjustment
		CopyFile(in_mat, out_mat)
		for c=1 to classes.length do
			//set files
			in_factors = input_dir + classes[c] + "_Adj_Factor.bin"  //SU_AdjFactor.bin or MU_AdjFactor.bin
			
			for t=1 to trip_types.length do
				core_name = classes[c] + "_" + trip_types[t]
				vw_name = classes[c] + "_Adj_Factor"
				
				RunMacro("FactorByIndex", out_mat, in_factors, core_name, "rowsum", "Yes")  //row factoring
				RunMacro("FactorByIndex", out_mat, in_factors, core_name, "colsum", "No")   //col factoring
			end
						
		end
	end 

endMacro


Macro "Start a File Writer" (outfile)

	if GetFileInfo(outfile) <> null then do
		DeleteFile(outfile)
	end
	
	fptr = OpenFile(outfile, "a")
	WriteLine(fptr, "TripType, Period, Matrix, Count, Sum, Mean, Std, SumDiag, PctDiag, Min, Max, MinRowId, MinColId, MaxRowId, MaxColId")
	
	
	Return(fptr)

endMacro

Macro "Get Model Zones"
	shared tazindex_file
	shared zones, zones_internal, zones_external
	
	//Set internal truck trips to 0
	//open daysim taz table
	//fields: Zone_id, Zone_ordinal, Dest_eligible, External
	tazindex_vw = OpenTable("tazindex_vw", "CSV", {tazindex_file},)	
	SetView(tazindex_vw)
	zones = GetDataVector(tazindex_vw+"|", "Zone_id", )
	
	qry1 = "Select * where External=0"
	n1 = SelectByQuery("Internal", "Several", qry1, )
	zones_internal = GetDataVector(tazindex_vw+"|Internal", "Zone_id", )

	qry2 = "Select * where External=1"
	n2 = SelectByQuery("External", "Several", qry2, )
	zones_external = GetDataVector(tazindex_vw+"|External", "Zone_id", )
	
	CloseView(tazindex_vw)

endMacro

Macro "FactorByIndex" (in_mat, in_factors, core_name, factor_field, apply_by_row)
	
	m = OpenMatrix(in_mat,)
	mc = CreateMatrixCurrency(m, core_name,,, )
	ok = (mc <> null)

	tab = OpenTable("tab", "FFB", {in_factors})
	vw_set = tab + "|"
	ok = (vw_set <> null)

    vec = RunMacro("TCB GetDataVector", vw_set, factor_field, {{"Match Matrix Index", {mc, "zone", apply_by_row}}})  // Match-matrix-index info array: {matrix_currency, id_field, apply_by_row}
    ok = (vec <> null)

    mc := nz(mc * vec)

endMacro
