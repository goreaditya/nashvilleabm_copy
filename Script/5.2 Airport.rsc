// Airport trips
// Steps - Trip Generation, Balance PA, Gravity Model Distribution
// Three trip purposes - AIR_HBO, AIR_NHBW, AIR_NHBO

Macro "Airport" (Args)
	
    shared Scen_Dir
 /*    
  // Standalone testing
    Scen_Dir  =  "C:\\Projects\\Nashville\\2010\\"
    Args.[taz] = "C:\\Projects\\Nashville\\2010\\2010TAZ.dbd"
    Args.[Household Production] = "C:\\Projects\\Nashville\\2010\\outputs\\householdPA.bin"
    Args.[daily enplanements] = 10400
    Args.[airport taz] = 3791255
    Args.[airport taz] = 226 // for new TAZ Ids
    Args.[zone_ones] = Scen_Dir+"outputs\\zone.mtx"
    Args.[Air_PA] = "C:\\Projects\\Nashville\\2010\\outputs\\airportPA.bin"
    Args.[Air_trip_dstr] = "C:\\Projects\\Nashville\\2010\\outputs\\airportTD.mtx"
    Args.[persons_per_room] = 1.8
*/

    RunMacro("TCB Init")
    
    // INPUTS
    sp           = SplitPath(Args.[taz])
    taz_file     = sp[1] + sp[2] + sp[3] + ".bin"           // SE-Data / TAZ file
    HH_PA_file   = Args.[Household Production]              // Household Production table
    enplanements = Args.[daily enplanements]                // Daily Enplanements
    airport_taz  = Args.[airport taz]                       // Airport TAZ #
    zones_mtx    = Scen_Dir+"outputs\\zone_airport.mtx"             // zone identity matrix
    persons_per_room = Args.[persons_per_room]              // Persons per hotel room
   
    // OUTPUTS
    air_PA    = Args.[Air_PA]                               // Balanced Airport PA table
    air_TD    = Args.[Air_trip_dstr]                        // Airport Trip Distribution matrix
    pth       = SplitPath(air_PA)
    air_unbal = pth[1] + pth[2] + pth[3] +"_unbal"+ pth[4]  // Unbalanced Airport PA table
    
//**** TRIP GENERATION FOR AIRPORT ****
    // Airport total trip attractions
    Total_air_attr = 1.3 * enplanements   
    
    Air_Trips = CreateTable("Air_Trips", air_unbal, "FFB", {
    		{"TAZ", "I", 10,},
     		{"AIR_HBO_P", "R", 10,2},
    		{"AIR_NHBW_P", "R", 10,2},
    		{"AIR_VISIT_P", "R", 10,2},
      		{"AIR_HBO_A", "R", 10,2},
    		{"AIR_NHBW_A", "R", 10,2},
    		{"AIR_VISIT_A", "R", 10,2}})
    
    // Open SE data and HH production tables
    taz_table = OpenTable("taz_table", "FFB", {taz_file})
    HH_PA_table = OpenTable("HH_PA_table", "FFB", {HH_PA_file})   
    
    rec_SE = GetFirstRecord(taz_table + "|", )
    
    While !(rec_SE=null) do
      
      values_SE = GetRecordValues(taz_table, , {"ID_NEW", "INCOME_25K", "INCOME_50K", "INCOME_75K", 
                                                "INCOME_100K", "INCOME_100KPLUS", "Hotel_Rooms", "Hotel_Occupancy"})
 
      rec_HH = LocateRecord(HH_PA_table + "|", "ID", {values_SE[1][2]}, {{"Exact", "True"}})
      values_HH = GetRecordValues(HH_PA_table, rec_HH, {"ID", "NHBW1"})      

      // Trip productions
      Air_HBO_prod  = 0.126 *  Nz(values_SE[2][2])
                    + 0.206 * (Nz(values_SE[3][2]) + Nz(values_SE[4][2])) 
                    + 0.668 * (Nz(values_SE[5][2]) + Nz(values_SE[6][2]))                      
      Air_NHBW_prod = values_HH[2][2]
      Air_Vist_prod = values_SE[7][2] * values_SE[8][2] * persons_per_room
         
      rh = AddRecord(Air_Trips, {{"TAZ", values_SE[1][2]},
                		         {"AIR_HBO_P", Air_HBO_prod},
    		                     {"AIR_NHBW_P", Air_NHBW_prod},
    		                     {"AIR_VISIT_P", Air_Vist_prod},
    		                     {"AIR_HBO_A",  "0"},
    		                     {"AIR_NHBW_A", "0"},
    		                     {"AIR_VISIT_A", "0"} })                         
      rec_SE = GetNextRecord(taz_table + "|", ,) 
      
    end
    
    // Trip attractions for the airport TAZ only      
    rh = LocateRecord(Air_Trips + "|", "TAZ", {airport_taz}, {{"Exact", "True"}})
    SetRecordValues(Air_Trips, rh, {{"AIR_HBO_A",  0.455 * Total_air_attr},
    		                        {"AIR_NHBW_A", 0.145 * Total_air_attr},
                                    {"AIR_VISIT_A", 0.4 * Total_air_attr} })
    CloseView(taz_table)
    CloseView(HH_PA_table)
    CloseView(Air_Trips)
    
//**** BALANCE PRODUCTIONS AND ATTRACTIONS FOR AIRPORT ****  
    Opts = null
    Opts.Input.[Data Set] = {air_unbal, "airportPA_unbal"}
    Opts.Input.[Data View] = {air_unbal, "airportPA_unbal"}
    Opts.Input.[V1 Holding Sets] = {, ,}
    Opts.Input.[V2 Holding Sets] = {, ,}
    Opts.Field.[Vector 1] = {"airportPA_unbal.AIR_HBO_P", "airportPA_unbal.AIR_NHBW_P", "airportPA_unbal.AIR_VISIT_P"}
    Opts.Field.[Vector 2] = {"airportPA_unbal.AIR_HBO_A", "airportPA_unbal.AIR_NHBW_A", "airportPA_unbal.AIR_VISIT_A"}
    Opts.Global.Pairs = 3
    Opts.Global.[Holding Method] = {2, 2, 2}
    Opts.Global.[Percent Weight] = {50, 50, 50}
    Opts.Global.[Sum Weight] = {100, 100, 100}
    Opts.Global.[V1 Options] = {1, 1, 1}
    Opts.Global.[V2 Options] = {1, 1, 1}
    Opts.Global.[Store Type] = 1
    Opts.Output.[Output Table] = air_PA
     
    ret_value = RunMacro("TCB Run Procedure", "Balance", Opts)
    if !ret_value then goto quit 
       
// Make a new zone-zone matrix of 1's - for TransCAD 8
	taz_table = OpenTable("taz_table", "FFB", {taz_file})
	CreateMatrix({taz_table+"|","ID_NEW","Rows"}, {taz_table+"|","ID_NEW","Columns"},
               {{"File Name",zones_mtx}, {"Type" ,"Short"}, {"Tables" ,{"Matrix 1"}}})
			   
	CloseView(taz_table)
			   
    Opts = null
    Opts.Input.[Matrix Currency] = {zones_mtx, "Matrix 1", "Rows", "Columns"}
    Opts.Global.Method = 1
    Opts.Global.Value = 1
    Opts.Global.[Cell Range] = 2
    Opts.Global.[Matrix Range] = 1
    Opts.Global.[Matrix List] = {"Matrix 1"}
    ret_value = RunMacro("TCB Run Operation", 1, "Fill Matrices", Opts)		   
	   
//**** GRAVITY MODEL FOR AIRPORT TRIP DISTRIBUTION ****
    Opts = null
    Opts.Input.[PA View Set] = {air_PA, "airportPA"}
    //Opts.Input.[FF Matrix Currencies] = {{zones_mtx, "Matrix 1",,}, {zones_mtx, "Matrix 1",,}, {zones_mtx, "Matrix 1",,}}
    //Opts.Input.[Imp Matrix Currencies]= {{zones_mtx, "Matrix 1",,}, {zones_mtx, "Matrix 1",,}, {zones_mtx, "Matrix 1",,}}
    //Opts.Input.[KF Matrix Currencies] = {{zones_mtx, "Matrix 1",,}, {zones_mtx, "Matrix 1",,}, {zones_mtx, "Matrix 1",,}}
	Opts.Input.[FF Matrix Currencies] = {, , }  // transCAD 8.0 
    Opts.Input.[Imp Matrix Currencies]= {{zones_mtx, "Matrix 1", "Rows", "columns"}, {zones_mtx, "Matrix 1", "Rows", "columns"}, {zones_mtx, "Matrix 1", "Rows", "columns"}} // transCAD 8.0 
    Opts.Input.[KF Matrix Currencies] = {{zones_mtx, "Matrix 1", "Rows", "columns"}, {zones_mtx, "Matrix 1", "Rows", "columns"}, {zones_mtx, "Matrix 1", "Rows", "columns"}} // transCAD 8.0 
    Opts.Input.[FF Tables] = {{air_PA}, {air_PA}, {air_PA}}
    //Opts.Field.[Prod Fields] = {"airportPA.AIR_HBO_P", "airportPA.AIR_NHBW_P", "airportPA.AIR_VISIT_P"}
    //Opts.Field.[Attr Fields] = {"airportPA.AIR_HBO_A", "airportPA.AIR_NHBW_A", "airportPA.AIR_VISIT_A"}
	Opts.Field.[Prod Fields] = {"AIR_HBO_P", "AIR_NHBW_P", "AIR_VISIT_P"} // transCAD 8.0 
    Opts.Field.[Attr Fields] = {"AIR_HBO_A", "AIR_NHBW_A", "AIR_VISIT_A"} // transCAD 8.0 
    //Opts.Field.[FF Table Fields] = {"airportPA.ID1", "airportPA.ID1", "airportPA.ID1"}
    Opts.Field.[FF Table Times] = {"airportPA.ID1", "airportPA.ID1", "airportPA.ID1"}
	Opts.Field.[FF Table Fields] = {"ID1", "ID1", "ID1"} // transCAD 8.0
    Opts.Global.[Purpose Names] = {"AIR_HBO", "AIR_NHBW", "AIR_VISIT"}
    Opts.Global.Iterations = {10, 10, 10}
    Opts.Global.Convergence = {0.01, 0.01, 0.01}
    //Opts.Global.[Constraint Type] = {"Columns", "Columns", "Columns"}
	Opts.Global.[Constraint Type] = {"Doubly", "Doubly", "Doubly"} // transCAD 8.0 
    //Opts.Global.[Fric Factor Type] = {"Matrix", "Matrix", "Matrix"}
	Opts.Global.[Fric Factor Type] = {"Gamma", "Gamma", "Gamma"} // transCAD 8.0
    Opts.Global.[A List] = {1, 1, 1}
    Opts.Global.[B List] = {0.3, 0.3, 0.3}
    Opts.Global.[C List] = {0.01, 0.01, 0.01}
	Opts.Global.[Minimum Friction Value] = {0, 0, 0} // transCAD 8.0
    //Opts.Flag.[Use K Factors] = {0, 0, 0}
    Opts.Output.[Output Matrix].Label = "Airport Trip Distribution, Daily"
    //Opts.Output.[Output Matrix].Compression = 1
    Opts.Output.[Output Matrix].[File Name] = air_TD

    ret_value = RunMacro("TCB Run Procedure", 1, "Gravity", Opts)
    if !ret_value then goto quit

    // Add airport trips to resident trips
    RunMacro("Merge_into_HBO", Args)
    Return(1)
    
    quit:
      Return(0)
    
endMacro


Macro "Merge_into_HBO" (Args)
  shared Scen_Dir
  
  OutDir = Scen_Dir+"outputs\\" 
  IDTable = Args.[IDTable]
  
  // Inputs
  resident_HBO = "HBO_PersonTrips2.mtx"  
  resident_NHBW = "NHBW_PersonTrips2.mtx"  
  resident_NHBO = "NHBO_PersonTrips2.mtx"  
  airport = Args.[Air_trip_dstr]
  
  // create new matrices
  RunMacro("Create a new matrix",OutDir,IDTable,resident_HBO,{"HBO1","HBO2","HBO3"})
  RunMacro("Create a new matrix",OutDir,IDTable,resident_NHBW,{"NHBW1"})
  RunMacro("Create a new matrix",OutDir,IDTable,resident_NHBO,{"NHBO1"})
  
  // change Airport matrix index - increase O/D from 2817 to 2900
  m = OpenMatrix(airport, )
  view = OpenTable("equivalancy", "FFB", {IDTable})
  new_index = CreateMatrixIndex("revised", m, "Both", view+"|", "NEWID", "NEWID",{{"Allow non-matrix entries","True"}})
  m = Null

  // Open matrices
  res_HBO = OpenMatrix(OutDir + resident_HBO,)
  res_NHBW = OpenMatrix(OutDir + resident_NHBW,)
  res_NHBO = OpenMatrix(OutDir + resident_NHBO,)
  air = OpenMatrix(airport,)
  
  // set hbo OD pairs values to zero
  hbo_matrix_cores = GetMatrixCoreNames(res_HBO)
  for c = 1 to hbo_matrix_cores.length do
    mc_res_hbo = CreateMatrixCurrency(res_HBO, hbo_matrix_cores[c], , ,)
    mc_res_hbo := nz(mc_res_hbo)
  end
  
  // Add resident airport HBO trips to HBO trips
  mc_res_hbo = CreateMatrixCurrency(res_HBO, "HBO2", , ,)
  mc_air_hbo = CreateMatrixCurrency(air, "AIR_HBO","revised","revised",)   
  mc_res_hbo := nz(mc_res_hbo) + nz(mc_air_hbo)

  // Add resident airport NHBW trips to NHBW trips
  mc_res_nhbw = CreateMatrixCurrency(res_NHBW, "NHBW1", , ,)
  mc_air_nhbw = CreateMatrixCurrency(air, "AIR_NHBW","revised","revised",)   
  mc_res_nhbw := nz(mc_res_nhbw) + nz(mc_air_nhbw)
    
  // Add Visitor trips to NHBO trips
  mc_res_nhbo = CreateMatrixCurrency(res_NHBO, "NHBO1", , ,)
  mc_air_visitor = CreateMatrixCurrency(air, "AIR_VISIT","revised","revised",)   
  mc_res_nhbo := nz(mc_res_nhbo) + nz(mc_air_visitor)
  
  // Close currencies
  mc_res_nhbo = null 
  mc_res_hbo  = null
  mc_res_nhbw = null
  mc_air_visitor  = null
  mc_air_nhbw  = null
  mc_air_hbo   = null
 
EndMacro