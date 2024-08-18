//Nashville Visitor Model
//Macro For (1) Preparing Input Data for Visitor Model, (2) Visitor Trip gen, (3) Visitor trip Distribution, (4) Visitor Mode Choice, and (5) Visitor Trip TOD
//This model generates visitor vehicle trip
//Can be run at any point between general network processing and main assignment

Macro "Visitor_Model" (Args)

	shared mf

	starttime = RunMacro("RuntimeLog", {"Visitor Model", null})
	RunMacro("HwycadLog", {"5 VisitorModel.rsc", "Run Visitor Model"})

	RunMacro("Settings", Args)
	RunMacro("TCB Init")

	tazvw    = RunMacro("AddLayer", mf.tazfile, "Area")
	linevw   = RunMacro("AddLayer", mf.linefile, "Line")
	nodevw   = GetNodeLayer(linevw)
	SetLayerVisibility(nodevw, "False")

	// 1. Preparing Input Data
	RunMacro("HwycadLog", {"Prepare input data", null})
	ok=RunMacro("01_Model_Inputs", tazvw)
	if (ok<>1) then goto quit
	
	// 2. Visitor Trip Gen
	RunMacro("HwycadLog", {"Visitor Trip Gen", null})
	ok=RunMacro("02_VTripGen", tazvw)
	if (ok<>1) then goto quit
	
	// 3. Visitor Trip Distribution
	RunMacro("HwycadLog", {"Visitor Trip Distribution", null})
	ok=RunMacro("03_VTripDist")
	if (ok<>1) then goto quit
	
	// 4. Visitor Trip Mode Choice
	RunMacro("HwycadLog", {"Visitor Trip Mode Choice", null})
	ok=RunMacro("04_VTripMC")
	if (ok<>1) then goto quit
	
	// 5. Visitor Trip Time of Day
	RunMacro("HwycadLog", {"Visitor Trip Time of Day", null})
	ok=RunMacro("05_VTripTOD")
	if (ok<>1) then goto quit

	ok=RunMacro("close all")
	if (ok<>1) then goto quit

	endtime = RunMacro("RuntimeLog", {"Visitor Model", starttime})	
	
	quit:
		Return(ok)	
	
endMacro

Macro "Settings" (Args)
	shared Scen_Dir, mf

	//INPUTS
	mf = null
	mf.path 			= Scen_Dir
	mf.hh_file 			= Args.[Households]
	mf.parcel_lu_file 	= Args.[Parcels]
	//tazindex_file 	= Args.[taz_index]
	
	mf.tazfile 			= Args.[taz]
	mf.netfile			= Args.[Network File]
	mf.linefile			= Args.[hwy db]
	mf.h_bed_file		= mf.path + "Inputs\\visitor\\SPECIAL_GEN.csv"
	mf.v_spec_gen		= mf.path + "Inputs\\visitor\\special_generators.bin"
	mf.skimfile			= Args.[md skim]
	mf.VKFactor			= mf.path + "Inputs\\visitor\\Visitor_KF.mtx"	
	
	//parameters
	mf.vis_sov			= 0.1
	mf.vis_sr2			= 0.35
	mf.vis_sr3			= 0.55
	mf.vis_am			= 0.095
	mf.vis_md			= 0.495
	mf.vis_pm			= 0.256
	mf.vis_op			= 0.154

	//outputs
	mf.output_path		= mf.path + "outputs\\"
	mf.V_PAfile			= mf.output_path + "Visitor_PA.bin"
	mf.intsel			= "TAZID < 3008" //TODO: make this dynamic
	mf.V_Distribution	= mf.output_path + "Visitor_OD.mtx"

endMacro

Macro "01_Model_Inputs" (tazvw)
	shared mf

	on error, notfound do
		goto quit
	end

	parcel_lu_file_vw = OpenTable("parcel_lu_file_vw", "CSV", {mf.parcel_lu_file},{{"Delimiter", " "}})
	hotel_file_vw = OpenTable("hotel_file_vw", "CSV", {mf.h_bed_file,})

	jnvw = JoinViews(parcel_lu_file_vw + hotel_file_vw, parcel_lu_file_vw+".parcelid", hotel_file_vw+".ID", {{"N", }}) //
	//Aggregate trips over some custom segments
	aggflds = {{"hh_p","sum",},{"ENROLL_UG","sum",},{"nodes3_1","sum",},{"nodes4_1","sum",},{"emptot_p","sum",},{"Hospital_Beds","sum",},{"Hotel_Beds","sum",}}
	
	SetView(jnvw)
	
	zonalfile = mf.output_path + "ZonalSE.bin"
	sevw = RunMacro("AggregateTable", jnvw+"|", "taz_p", aggflds, zonalfile)
	CloseView(jnvw)

	hh_file_vw = OpenTable("hh_file_vw", "CSV", {mf.hh_file},{{"Delimiter", " "}})
	
	//Aggregate trips over some custom segments
	aggflds = {{"hhincome","avg",}}
	
	SetView(hh_file_vw)
	
	hhincfile = mf.output_path + "AvgInc.bin"
	hhvw = RunMacro("AggregateTable", hh_file_vw+"|", "hhtaz", aggflds, hhincfile)

	zonevw = OpenTable("zonevw", "FFB", {mf.output_path + "ZonalSE.bin",})
	RunMacro("addfields", zonevw, {"Intersection", "IntDensx1000000", "AvgInc", "Spec_Gen", "SpecGen_Coeff"}  , {"i","r","r","i","r"})
	{TAZID, Int3, Int4} = GetDataVectors(zonevw + "|", {"taz_p","nodes3_1","nodes4_1"}, {{"Sort Order",{{"taz_p","Ascending"}}}} )

	{TAZ, ZoneArea} = GetDataVectors(tazvw + "|", {"ID", "SHAPE_AREA"}, {{"Sort Order",{{"ID","Ascending"}}}} )
	
	specvw = OpenTable("specvw", "FFB", {mf.v_spec_gen,})
	
	
	hhvw = OpenTable("hhvw", "FFB", {mf.output_path + "AvgInc.bin",})

	tazcount = VectorStatistic(TAZID, "Count", )
	zerovec = Vector(tazcount, "Long", {{"Constant", 0}})
	Intersection = nz(Int3) + nz(Int4)
	IntscnDens = Intersection*1000000/ZoneArea
	SetDataVectors(zonevw+"|", {{"Intersection", Intersection}, {"IntDensx1000000", IntscnDens}, {"AvgInc", zerovec}, {"Spec_Gen", zerovec}}, {{"Sort Order",{{zonevw+".taz_p","Ascending"}}}})
	
	jnvw = JoinViews(zonevw + hhvw, zonevw+".taz_p", hhvw+".hhtaz", {{"I", }})
	HHIncome = GetDataVector(jnvw+"|", "AVG hhincome", {{"Sort Order",{{"taz_p","Ascending"}}}} )
	SetDataVector(jnvw+"|", "AvgInc", HHIncome, {{"Sort Order",{{"taz_p","Ascending"}}}})
	Closeview(jnvw)
	

	jnvw = JoinViews(zonevw + specvw, zonevw+".taz_p", specvw+".TAZID", {{"I", }})
	SetView(jnvw)
	int_zones = SelectByQuery("Internal", "Several", "Select * where "+mf.intsel,)
	{special, Coefficient} = GetDataVectors(jnvw + "|Internal", {"TAZID", "Coeff"}, {{"Sort Order",{{"TAZID","Ascending"}}}} )
	SetDataVectors(jnvw+"|Internal", {{"Spec_Gen", special}, {"SpecGen_Coeff", Coefficient}}, {{"Sort Order",{{zonevw+".taz_p","Ascending"}}}})
	CloseView(jnvw)
	
	SetView(zonevw)
	RunMacro("addfields", zonevw, {"TAZID"}  , {"i"})
	{taz, special, coeffs} = GetDataVectors(zonevw + "|", {"taz_p", "Spec_Gen", "SpecGen_Coeff"}, {{"Sort Order",{{"taz_p","Ascending"}}}} )
	specgen = if special > 0 then 1 else 0
	SG_coeffs = if coeffs > 0 then coeffs else 0
	SetDataVectors(zonevw+"|", {{"Spec_Gen", specgen}, {"SpecGen_Coeff", SG_coeffs}, {"TAZID", taz}}, {{"Sort Order",{{zonevw+".taz_p","Ascending"}}}})

	
	CloseView(zonevw)
	CloseView(parcel_lu_file_vw)
	CloseView(hotel_file_vw)
	CloseView(hh_file_vw)
	CloseView(hhvw)
	CloseView(specvw)

	ok=1
	quit:
		Return(ok)
	
endMacro

Macro "02_VTripGen" (tazvw)
	shared mf
	
	on error, notfound do
		goto quit
	end

	V_TG = CreateTable("V_TG", mf.V_PAfile,"FFB", {
						{"TAZID"         , "Integer", 16, null, "No"},
						{"V_Prod"        , "Real"   , 12, 2   , "No"}, 
						{"V_Attr"        , "Real"   , 12, 2   , "No"}							
					})

	SetView(tazvw)

	tazidv = GetDataVector(tazvw+"|", "ID", {{"Sort Order",{{"ID","Ascending"}}}} )
	tazcount = VectorStatistic(tazidv, "Count", )

	r = AddRecords(V_TG, null, null, {{"Empty Records", tazcount}})
	SetDataVectors(V_TG+"|",{ {"TAZID",tazidv} }  ,{{"Sort Order",{{"TAZID","Ascending"}}}})					
					
	// Variables For Trip Gen
	zonevw = OpenTable("zonevw", "FFB", {mf.output_path + "ZonalSE.bin",})
	SetView(zonevw)


	{TAZID,HH,Tot_Emp,SpecGen,IntDens,AvgInc,Hospital,UgStd,SpecCoeff} = GetDataVectors(zonevw + "|", {"TAZID","hh_p","emptot_p","Spec_Gen","IntDensx1000000","AvgInc","HOSPITAL_BEDS","ENROLL_UG","SpecGen_Coeff"}, {{"Sort Order",{{"TAZID","Ascending"}}}} )

	SetView(tazvw)
	
	//Trip production coefficients
	HH_Coef = 0.0189
	Inc_Coef = 0.0000748
	Emp_Low_Coef = 0.0468
	Emp_High_Coef = 0.00573			 
	Hospital_Coef = 0.274
	StdUg_Coef = 0.00887
	IntDens_Coef = 13759

	//Productions & Attractions
	Visitor_Prod = if Tot_Emp < 5000 then (HH_Coef * HH + Emp_Low_Coef * Tot_Emp + Inc_Coef * AvgInc + Hospital_Coef * Hospital + IntDens * IntDens_Coef/1000000 + StdUg_Coef * UgStd + SpecGen*Tot_Emp*SpecCoeff) else 
			  (HH_Coef * HH + Emp_High_Coef * Tot_Emp + Inc_Coef * AvgInc + Hospital_Coef * Hospital + IntDens * IntDens_Coef/1000000 + StdUg_Coef * UgStd + SpecGen*Tot_Emp*SpecCoeff) 	

	Visitor_Attr = Visitor_Prod

	SetDataVectors(V_TG + "|", {{"V_Prod",Visitor_Prod},{"V_Attr",Visitor_Attr}},{{"Sort Order",{{"TAZID","Ascending"}}}})

	Closeview(V_TG)

	linevw   = RunMacro("AddLayer", mf.linefile, "Line")
	nodevw   = GetNodeLayer(linevw)

	SetView(nodevw)
	nint = SelectByQuery("Selection", "Several", "Select * where TAZID > 0",) //Centroids
	autovismat = CreateMatrix({nodevw+"|Selection", nodevw+".ID", "NodeID"}, {nodevw+"|Selection", nodevw+".ID", "NodeID"}, {{"File Name", mf.V_Distribution}, {"Type", "Float"}, {"Tables", {"Auto"}}})
	RunMacro("CheckMatrixIndex", autovismat, "TAZID", "TAZID", nodevw, "Select * where TAZID > 0", "TAZID", "ID")
	RunMacro("CheckMatrixIndex", autovismat, "Internal", "Internal", nodevw, "Select * where "+mf.intsel, "ID", "ID")
	
	ok=1
	quit:
		Return(ok)

endMacro

Macro "03_VTripDist" 
	shared mf
	//mf = RunMacro("LoadConfig", info.modcfg)
	
	on error, notfound do
		goto quit
	end
	
	
	//SET of Impedance currencies
	impskim = {mf.skimfile,"Length","TAZ_ID","TAZ_ID"}
	Visitor_KF = {mf.VKFactor,"Visitor","Row ID's","Col ID's"}
	
		RunMacro("TCB Init")

	// STEP 1: Gravity
		Opts = null
		Opts.Input.[PA View Set] = {mf.V_PAfile,}
		Opts.Input.[KF Matrix Currencies] = {Visitor_KF}
		Opts.Input.[FF Tables] = {}
		Opts.Input.[Imp Matrix Currencies] = {impskim}
		Opts.Input.[FF Matrix Currencies] = {}
		Opts.Global.[Constraint Type] = {"Doubly"}
		Opts.Global.[Purpose Names] = {"Auto"}
		Opts.Global.Iterations = {100}
		Opts.Global.Convergence = {0.001}
		Opts.Global.[Fric Factor Type] = {"Gamma"}
		Opts.Global.[A List] = {4393.841349}
		Opts.Global.[B List] = {1.089942}
		Opts.Global.[C List] = {0.065423}
		Opts.Global.[Minimum Friction Value] = {0}
		Opts.Field.[Prod Fields] = {"V_Prod"}
		Opts.Field.[Attr Fields] = {"V_Attr"}
		Opts.Field.[FF Table Times] = {}
		Opts.Field.[FF Table Fields] = {}
		Opts.Output.[Output Matrix].Label = "Gravity Matrix"
		Opts.Output.[Output Matrix].Compression = 1
		Opts.Output.[Output Matrix].[File Name] = mf.output_path + "TempVisitor.mtx"
		ok = RunMacro("TCB Run Procedure", "Gravity", Opts, &Ret)

		if !ok then Return( RunMacro("TCB Closing", ok, True ) )

	visitormat = OpenMatrix(mf.V_Distribution, )	
	vismtx = CreateMatrixCurrency(visitormat,"Auto","Internal","Internal",)   
	gravity = OpenMatrix(mf.output_path + "TempVisitor.mtx", )
	gravitymtx = CreateMatrixCurrency(gravity,"Auto","Row ID's","Col ID's",)   
	vismtx := gravitymtx

	ok=1
	quit:
		Return(ok)
		
endMacro

Macro "04_VTripMC" 
	shared mf
	//mf = RunMacro("LoadConfig", info.modcfg)
	
	on error, notfound do
		goto quit
	end	
	
	visitormat = OpenMatrix(mf.V_Distribution, )	
	sovmtx = RunMacro("CheckMatrixCore", visitormat, "SOV", "TAZID", "TAZID")
	sr2mtx = RunMacro("CheckMatrixCore", visitormat, "SR2", "TAZID", "TAZID")
	sr3mtx = RunMacro("CheckMatrixCore", visitormat, "SR3", "TAZID", "TAZID")
	visTmtx = CreateMatrixCurrency(visitormat,"Auto","TAZID","TAZID",)  
	
	//sovmtx := s2r(mf.vis_sov) * visTmtx
	//sr2mtx := s2r(mf.vis_sr2) * visTmtx
	//sr3mtx := s2r(mf.vis_sr3) * visTmtx

	sovmtx := mf.vis_sov * visTmtx
	sr2mtx := mf.vis_sr2 * visTmtx
	sr3mtx := mf.vis_sr3 * visTmtx

	ok=1
	quit:
		Return(ok)
		
endMacro

Macro "05_VTripTOD" 
	shared mf
	//mf = RunMacro("LoadConfig", info.modcfg)
	
	on error, notfound do
		goto quit
	end	
	
	visitormat = OpenMatrix(mf.V_Distribution, )	
	sovammtx = RunMacro("CheckMatrixCore", visitormat, "SOV_AM", "TAZID", "TAZID")
	sovmdmtx = RunMacro("CheckMatrixCore", visitormat, "SOV_MD", "TAZID", "TAZID")
	sovpmmtx = RunMacro("CheckMatrixCore", visitormat, "SOV_PM", "TAZID", "TAZID")
	sovopmtx = RunMacro("CheckMatrixCore", visitormat, "SOV_OP", "TAZID", "TAZID")
	
	sr2ammtx = RunMacro("CheckMatrixCore", visitormat, "SR2_AM", "TAZID", "TAZID")
	sr2mdmtx = RunMacro("CheckMatrixCore", visitormat, "SR2_MD", "TAZID", "TAZID")
	sr2pmmtx = RunMacro("CheckMatrixCore", visitormat, "SR2_PM", "TAZID", "TAZID")
	sr2opmtx = RunMacro("CheckMatrixCore", visitormat, "SR2_OP", "TAZID", "TAZID")
	
	sr3ammtx = RunMacro("CheckMatrixCore", visitormat, "SR3_AM", "TAZID", "TAZID")
	sr3mdmtx = RunMacro("CheckMatrixCore", visitormat, "SR3_MD", "TAZID", "TAZID")
	sr3pmmtx = RunMacro("CheckMatrixCore", visitormat, "SR3_PM", "TAZID", "TAZID")
	sr3opmtx = RunMacro("CheckMatrixCore", visitormat, "SR3_OP", "TAZID", "TAZID")
	
	sovmtx = CreateMatrixCurrency(visitormat,"SOV","TAZID","TAZID",)  
	sr2mtx = CreateMatrixCurrency(visitormat,"SR2","TAZID","TAZID",)  
	sr3mtx = CreateMatrixCurrency(visitormat,"SR3","TAZID","TAZID",)  
	
	sovammtx := mf.vis_am * sovmtx
	sovmdmtx := mf.vis_md * sovmtx
	sovpmmtx := mf.vis_pm * sovmtx
	sovopmtx := mf.vis_op * sovmtx
		
	sr2ammtx := mf.vis_am * sr2mtx
	sr2mdmtx := mf.vis_md * sr2mtx
	sr2pmmtx := mf.vis_pm * sr2mtx
	sr2opmtx := mf.vis_op * sr2mtx
		
	sr3ammtx := mf.vis_am * sr3mtx
	sr3mdmtx := mf.vis_md * sr3mtx
	sr3pmmtx := mf.vis_pm * sr3mtx
	sr3opmtx := mf.vis_op * sr3mtx

	ok=1
	quit:
		Return(ok)
		
endMacro




Macro "LoadConfig" (csvfile)
//csvfile: Description, Input, VariableName 
// Make sure the path is correct for your installation of TransCAD
fptr = OpenFile(csvfile, "r")

while not FileAtEOF(fptr) do
    thisline = ReadLine(fptr)
	cfgcol = ParseString(thisline, ",")
	if cfgcol[1] = "Description" then goto skip
	if cfgcol[2] = "null" or cfgcol[2] = "" then cfgcol[2] = null
	modelcfg = modelcfg + {{cfgcol[3], cfgcol[2]}}
skip:
end

CloseFile(fptr)
Return(modelcfg)
endMacro

//Mapping
Macro "AddLayer" (file, type)
//Adds .dbd to map as a layer
//Type: "Point", "Line", or "Area" for geographic layers, "Image" for image layers, or "Image Library" for image libraries

map_name = GetMap()
layer_names = GetLayerNames()
file_layers = GetDBLayers(file)
file_info = GetDBInfo(file)
if map_name = null then map_name = CreateMap("RSG", {{"Scope", file_info[1]}, {"Auto Project", "True"}})
SetMapRedraw(map_name, "False")

//If .rts then add to map
if type = "rts" then do
	newlyr = AddRouteSystemLayer(null, "Transit Routes", file, null)
	RunMacro("Set Default RS Style", newlyr, "True", "True")
	Return(newlyr[1])
	//[1] Route System Layer Name
	//[2] Stops
	//[3] Physical Stops
	//[4] Node Layer Name (if added)
	//[5] Line Layer Name (if added)
end

//Check if db already exists
for i=1 to layer_names.length do
	//Skip if Type mismatch
	layer_type = GetLayerType(layer_names[i])
	if layer_type <> type then goto skip
	
	//Check for dbd match
	layer_info = GetLayerInfo(layer_names[i])
	layerdb = layer_info[10]
	if lower(layerdb) = lower(file) then do
		//ShowMessage("AddLayer: LayerDB already exists in map")
		Return(layer_names[i])
	end
	skip:
end

/*
//Check if layername already exists
for i=1 to file_layers.length do
	idx = ArrayPosition(layer_names, {file_layers[i]}, ) 
	if idx <> 0 and GetLayerType(file_layers[i]) = type then do
		newlyr = layer_names[idx]
		//ShowMessage("AddLayer: LayerName already exists")
		Return(newlyr)
	end
end
*/

//Else, add file to map
newlyr = AddLayer(null, file_layers[1], file, file_layers[1])
if GetLayerType(newlyr) <> type then do
	newlyr = AddLayer( , file_layers[2], file, file_layers[2]) //Add lines if only nodes were loaded
end
RunMacro("G30 new layer default settings", newlyr)
Return(newlyr)

endhere:
throw("AddLayer: Layer already exists in map!")

endMacro

Macro "AggregateTable" (vwset, groupfld, aggflds, outbin)
	aggvw = AggregateTable("AggTable",vwset,"FFB",outbin,groupfld,aggflds,)
	Return(aggvw)
endMacro

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

Macro "CheckMatrixIndex" (mtx, rowidx, colidx, view, qry, oldid, newid)
	idxexists = 0
	idxnames = GetMatrixIndexNames(mtx)

	if rowidx <> null then do
		for i=1 to idxnames[1].length do
			if idxnames[1][i] = rowidx then idxexists = 1
		end
	end
	if colidx <> null then do
		for i=1 to idxnames[2].length do
			if idxnames[2][i] = colidx then idxexists = 1
		end
	end

	if idxexists = 1 then do 
		Return()
	end
	else if idxexists = 0 then do
		SetView(view)
		set = SelectByQuery(rowidx, "Several", qry, )
		newidx = CreateMatrixIndex(rowidx, mtx, "Both", view+"|"+rowidx, oldid, newid)
		DeleteSet(rowidx)
		Return()
	end
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

Macro "close all"
  maps = GetMaps()
  if maps <> null then do
    for k = 1 to maps[1].length do
      SetMapSaveFlag(maps[1][k],"False")
    end
  end
  RunMacro("G30 File Close All")
  mtxs = GetMatrices()
  if mtxs <> null then do
    handles = mtxs[1]
    for k = 1 to handles.length do
      handles[k] = null
    end
  end
  views = GetViews()
  if views <> null then do
    handles = views[1]
    for k = 1 to handles.length do
      handles[k] = null
    end
  end
  Return(1)
EndMacro
