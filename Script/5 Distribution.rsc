/*****************************************************************************************
                                      Part 6                     
                                Destination Choice             
******************************************************************************************/
// Create Logsums First
Macro "ModeChoiceLogSums"(Args)
    shared Scen_Dir
    purposes = {"hbw","hbo","hbshp","hbpd","hbsch","nhbw","nhbo"}
    RunMacro("TCB Init")
   
    // Re-index the skims to run JAVA based Modechoice model
    ok = RunMacro("ProcessTransitSkimsforMC", Args)
    if !ok then goto quit
    
    // Create batchfiles by purpose
    for p = 1 to purposes.length do
       batfile = RunMacro("CreateBatch",purposes[p],3)
    end
    
    // Compute Logsums in Parallel
    ok = RunMacro("Run in Parallel", {{Scen_Dir + "reference\\mchoice\\hbw.cmd"  , 1},
                                      {Scen_Dir + "reference\\mchoice\\hbo.cmd"  , 1},
                                      {Scen_Dir + "reference\\mchoice\\hbshp.cmd", 1}})
    if !ok then goto quit
      
    ok = RunMacro("Run in Parallel", {{Scen_Dir + "reference\\mchoice\\hbpd.cmd" ,1},
                                      {Scen_Dir + "reference\\mchoice\\hbsch.cmd",1},
                                      {Scen_Dir + "reference\\mchoice\\nhbw.cmd" ,1},
                                      {Scen_Dir +"reference\\mchoice\\nhbo.cmd"  ,1}})
    if !ok then goto quit  
      
    // Re-index the skims to run JAVA based Modechoice model
    ok = RunMacro("ChangeMatrixIndicesAfterLogSums",Args)
    if !ok then goto quit      
     
    ok = 1

   quit:
    Return(ok)
EndMacro

Macro "Run in Parallel" (bacthfiles)
    shared Scen_Dir
    
    // Set environment variables for paths used in bat file
    {scen_drive, scen_dir,,} = SplitPath(Scen_Dir)
    SetEnvironmentVariable("Nashville_DRIVE", scen_drive)
    SetEnvironmentVariable("Nashville_DIR", scen_dir)    

    Opts = null
    Opts.Files = bacthfiles
    Opts.ForceOneProcess=false
    Opts.MaxProcessors= 3
    ok = RunMacro("LaunchPrograms", Opts)
    ok = 1
 
   quit:
    SetEnvironmentVariable("Nashville_DRIVE", "")
    SetEnvironmentVariable("Nashville_DIR", "")
    Return(ok)
EndMacro


Macro "CreateBatch"(purpose, mctype) 
    shared Scen_Dir
    
    batFile = Scen_Dir + "reference\\mchoice\\"+purpose+".cmd"
    tcadFullPath = GetProgram()
    tcadPath  = Substring(tcadFullPath[1],,StringLength(tcadFullPath[1])-8)
    
    batch = OpenFile(batFile,"w")
       WriteLine(batch, '%Nashville_DRIVE%'             )
       WriteLine(batch, 'cd "%Nashville_DIR%"'          )
       WriteLine(batch,                                 )
       WriteLine(batch, 'set OLDPATH=%PATH%'            )
       WriteLine(batch, 'set OLDJAVAPATH=%JAVA_PATH%'   )
       WriteLine(batch, 'set JAVA_PATH="C:\\Program Files\\Java\\jre7"')
       WriteLine(batch, 'set TRANSCAD_LIB='+tcadPath)
       WriteLine(batch, 'set PATH='+tcadPath+'\\;'+tcadPath+'\\GISDK\\Matrices\\;%JAVA_PATH%\\bin;%OLDPATH%')
       WriteLine(batch, 'set CLASSPATH=%Nashville_DIR%\\reference\\mchoice;%Nashville_DIR%\\reference\\mchoice\\nashvilleMC.jar;%TRANSCAD_LIB%\\GISDK\\Matrices\\TranscadMatrix.jar')
       WriteLine(batch,                                 )
       WriteLine(batch, "java -Xms2000m -Xmx2000m -Dlog4j.configuration=info_log4j.xml com.pb.nashville.modeChoice.ModeChoiceApplication reference\\mchoice\\"+purpose+".properties "+ String(mctype)+" "+Upper(purpose))
       WriteLine(batch, ' '                                )
       WriteLine(batch, 'if not exist "outputs\\logsum_'+purpose+'.mtx"  exit 1')
       WriteLine(batch, 'exit 0'                        )
       WriteLine(batch, '')
       WriteLine(batch, 'set JAVA_PATH=%OLDJAVAPATH%'   )
       WriteLine(batch, 'set PATH=%OLDPATH%'            )
       WriteLine(batch, 'set CLASSPATH=%OLDCLASSPATH%'  )
    CloseFile(batch)
    Return(batFile)   
EndMacro

/*
  Standalone test settings
*/
Macro "Test DC Model"
     shared scen_data_dir
     
     RunMacro ("TCB Init")
     
     // Optional arguments: When this model is run by hand, user can pass in optional arguments 
     // to run only selected purpose
     run_select_pur = 1                                                                   // 1 or 0 
     pur            = {"HBW"} // ,"NHBO","NHBW"}                                               // or any other purpose or list of purposes
     
     // Input file settings: 
     scen_data_dir               = "D:\\2040 Model\\2010\\"
     Args ={}                 
     Args.[Household Production] = scen_data_dir + "outputs\\householdPA.bin"             // trip productions
     Args.[am skim]              = scen_data_dir + "outputs\\hwyskim_am.mtx"              // AM_TIME (Skim)
     Args.[op skim]              = scen_data_dir + "outputs\\hwyskim_op.mtx"              // OFF_TIME (Skim)
     Args.[taz]                  = scen_data_dir + "2010taz.dbd"                          // TAZ_2010
     Args.Coeff_DC_Size          = scen_data_dir + "dc\\DC_purp_mseg_constants.bin"       // constants by purpose and market segment
     Args.[Retain DC Logsums]    = 1                                                      // 0 = Don't retain
     
     // Run the DC model
     // ok = RunMacro("Distribution - Household", Args, run_select_pur, tps, pur)
     ok = RunMacro("Distribution - Household", Args, run_select_pur, pur)
     if ok  then ShowMessage("Model run is complete !!!")
      
EndMacro

     
/*
  DC Model Settings
  Applies DC Model by trip purpose and auto groups
  
  // Inputs: 
  Args.[am skim]        : Highway peak skim
  Args.[op skim]        : Highway offpeak skim
  logsums_<purpose>.mtx : LogSums by trip purpose (daily)
  Args.Coeff_DC_Size    : Destination choice model coefficients
  
  // Parametes: 
  Args.[Retain DC Logsums] : Boolean to delete logsums after DC Model application 
  
*/

Macro "Distribution - Household" (Args, run_select_pur, pur)
     shared scen_data_dir, Scen_Dir
    
     // Escape key routine
     on escape, error, notfound do
         ErrorMsg = GetLastError()
         ret_value = 0
         goto quit
     end
     
     // Run by trip purpose: run 15 iters for HBW, and 1 for others
     hwypk      =  Args.[am skim]   // uses peak distance for HBW & NHBW 
     hwyop      =  Args.[op skim]   // uses offpeak distance for all except HBW & NHBW 
     
     pnames          = {"HBO","HBPD","HBSch", "HBShp", "HBW", "NHBO","NHBW"}
     auto_suff       = {    3,     1,      1,       3,     3,      1,    1}
     piters          = {    1,     1,      1,       1,    15,      1,    1}
     dist_skim       = {hwyop, hwyop,  hwyop,   hwyop, hwypk,  hwyop, hwypk}
      
     retainDCLogsums        = Args.[Retain DC Logsums] 
     sufficiency_categories = {"HH_0_Auto","HH_1_Auto","HH_2plus_Auto"}  
     
     // Replace default settings with the user selected (for test model)
     if (run_select_pur =1) then do
       for x = 1 to pnames.length do
         for y = 1 to pur.length do
          if pur[y] = pnames[x] then do 
            sel_auto_suff = sel_auto_suff+{auto_suff[x]} 
            sel_piters    = sel_piters+{piters[x]}
            sel_skims     = sel_skims+{dist_skim[x]}
          end
         end
       end
       
       // reset purpose, auto group and iterations
       auto_suff = sel_auto_suff
       piters    = sel_piters 
       pnames    = pur  
       dist_skim = sel_skims    
     end        

     // Inputs (SE data and trip productions)
     pa_tab         = Args.[Household Production]
     tazpoly_info   = SplitPath(Args.[taz])
     model_sed    = tazpoly_info[1]+ tazpoly_info[2] +tazpoly_info[3] + ".bin"
     
     // Save attractions for HBW
     newTable = scen_data_dir + "outputs\\temp.bin"

    // Loop by purpose      
    for p = 1 to pnames.length do
      Args.[DA Skims] = dist_skim[p]
      Args.Iters      = piters[p]
      Args.PNAME      = pnames[p]
      
      // Loop by iterations
      for i = 1 to piters[p] do
          
          //----------------------------------------------------------------------------------------
          // Initialize variables and vectors 
          if (i = 1) then do 
             
             // Define zones
             sedtab = OpenTable("Model SED", "FFB", {model_sed})
             pa_vw  = OpenTable("PATAB", "FFB", {pa_tab}) 
             zdata_vw = JoinViews("jv", sedtab + ".ID", pa_vw + ".ID",)
             SetView(zdata_vw)
     
             // Get total employment
             Emp_array = {"EMP_ARG", "EMP_MANU", "EMP_RET", "EMP_TRANS", "EMP_OFFICE", "HH10", "STUDENT_K12",  "COLLEGE"} 
             tazlab="["+sedtab+"].ID"
             emp=GetDataVectors(zdata_vw + "|",Emp_array,{{"Sort Order",{{tazlab,"A"}}}}) 
             for e = 1 to Emp_array.length do 
               if e=1 then emp_vec = emp[e] else emp_vec = emp_vec + emp[e] 
             end
             
             // Get number of zones 
             zones_vec = GetDataVector(zdata_vw + "|",tazlab,{{"Sort Order",{{tazlab,"A"}}}})
             zones = emp[1].length 

             // Create output table to save attractions
             attr_vw = CreateTable("HBW Attr", newTable, "FFB", {
                                    {"ID", "Integer", 10, null, "No"}, 
                                    {"HBW1_Attr", "Float", 10, 4, "No"}, 
                                    {"HBW2_Attr", "Float", 10, 4, "No"},  
                                    {"HBW3_Attr", "Float", 10, 4, "No"},
                                    {"Tot_Attr", "Float", 10, 4, "No"},
                                    {"Emp", "Float", 10, 4, "No"},
                                    {"Scaled_Emp", "Float", 10, 4, "No"},
                                    {"Shadow_Price", "Float", 10, 4, "No"}
                                   })
             // Add records      
             for z = 1 to zones_vec.length do
                rh = AddRecord(attr_vw, {{"ID", zones_vec[z]}})
             end

             // Create a dummy shadow price for the first iteration
             CF = Vector(zones, "Float", {{"Constant",0},{"Row Based","True"}})
     
             // Open file to write out attraction vectors
             attr_out = scen_data_dir+"outputs\\CF_"+Args.PNAME+".txt"
             outfile = OpenFile(attr_out,"w")
             WriteArray(outfile, v2a(CF))
             CloseFile(outfile)
             CopyFile(attr_out, scen_data_dir+"outputs\\CF_"+Args.PNAME+String(i)+".txt")
             
             // Close views
             CloseView(zdata_vw)
             CloseView(sedtab)
             CloseView(pa_vw)
          end
          
          //----------------------------------------------------------------------------------------
          // Loop by auto group and apply destination choice model
          for a = 1 to auto_suff[p] do
             
             // LogSum by purpose 
             Args.Logsums  = scen_data_dir + "outputs\\logsum_"+Lower(pnames[p])+"_2.mtx" 
             
             // LogSum core based on auto group
             if auto_suff[p] = 1 then 
               Args.coreName = Lower(pnames[p])+"_logsum" else
               Args.coreName = Lower(pnames[p])+String(a-1)+"a_logsum"
               
             // Run DC Model  
             ok = RunMacro("DC_Application", Args,a)
          
          end // auto market

          //----------------------------------------------------------------------------------------
          // Compute shadow price for HBW market
          if Args.PNAME = "HBW" then do
              // purpose
              pnam = "HBW"
              
              // Open triptables by auto market
              ptripf = scen_data_dir + "outputs\\"+pnam+"_PersonTrips.mtx"
              permat = OpenMatrix(ptripf,)
              label  = pnam + String(autoSuffNumber)
              tripsmc_1 = CreateMatrixCurrency(permat, pnam + String(1), "Zones", "Zones",)
              tripsmc_2 = CreateMatrixCurrency(permat, pnam + String(2), "Zones", "Zones",)
              tripsmc_3 = CreateMatrixCurrency(permat, pnam + String(3), "Zones", "Zones",)
              
              // Compute attractions and shadow price for doubly-constraining
              attractions_1 = GetMatrixVector(tripsmc_1, {{"Marginal", "Column Sum"}})
              attractions_2 = GetMatrixVector(tripsmc_2, {{"Marginal", "Column Sum"}})
              attractions_3 = GetMatrixVector(tripsmc_3, {{"Marginal", "Column Sum"}})      
                    
              // Total attractions
              attractions = attractions_1+ attractions_2 + attractions_3
                            
              // Scale total employment to total attractions (balance P & A's)
              total_emp  = VectorStatistic(emp_vec, "Sum",)
              total_attr = VectorStatistic(attractions, "Sum",)
              scale_emp  = emp_vec * (total_attr/total_emp)
             
              // Read previous shadow price 
              attr_out = scen_data_dir+"outputs\\CF_"+Args.PNAME+".txt"
              outfile = OpenFile(attr_out,"r")
              CF_prev_arr = ReadArray(outfile)
              for arr = 1 to CF_prev_arr.length do
                 CF_prev_arr[arr] = Value(CF_prev_arr[arr])
              end
              CF_prev = A2V(CF_prev_arr)
              CloseFile(outfile)
              
              // Compute shadow price
              CF = CF_prev + log(scale_emp/attractions)
              
              // Write out shadow price
              outfile = OpenFile(attr_out,"w")
              WriteArray(outfile, v2a(CF))
              CloseFile(outfile)
              CopyFile(attr_out, scen_data_dir+"outputs\\CF_"+Args.PNAME+"_iter_"+String(i)+".txt")

              // Writeout some info
              attr_vw = OpenTable("HBW Attr", "FFB", {newTable})
              SetDataVector(attr_vw+"|","HBW1_Attr",attractions_1,{{"Sort Order",{{"ID","A"}}}})
              SetDataVector(attr_vw+"|","HBW2_Attr",attractions_2,{{"Sort Order",{{"ID","A"}}}})
              SetDataVector(attr_vw+"|","HBW3_Attr",attractions_3,{{"Sort Order",{{"ID","A"}}}})
              SetDataVector(attr_vw+"|","Tot_Attr",attractions,{{"Sort Order",{{"ID","A"}}}})
              SetDataVector(attr_vw+"|","Emp",emp_vec,{{"Sort Order",{{"ID","A"}}}})
              SetDataVector(attr_vw+"|","Scaled_Emp",scale_emp,{{"Sort Order",{{"ID","A"}}}})
              SetDataVector(attr_vw+"|","Shadow_Price",CF,{{"Sort Order",{{"ID","A"}}}})
              
              ExportView(attr_vw+"|","CSV", scen_data_dir+"outputs\\HBW_attrations_iter_"+String(i)+".csv",,{{"CSV Header", "True"}})
              CloseView(attr_vw)
              tripsmc_1 = Null
              tripsmc_2 = Null
              tripsmc_3 = Null
              permat    = Null

              mtxs = GetMatrices()
              if mtxs <> null then do
                handles = mtxs[1]
                for i = 1 to handles.length do
                  handles[i] = null
                end
              end
              //----------------------------------------------------------------------------------------
              // Convergence criteria
              convergence = 0.01
              diff_attr = nz(abs((scale_emp - attractions)/scale_emp))
              for z = 1 to scale_emp.length do
                 if(scale_emp[z] = 0 or attractions[z] =0) then diff_attr[z] = 0
              end
              diff_attr_max = VectorStatistic(diff_attr, "Max",)
              if diff_attr_max <= convergence then goto converged
                
              //----------------------------------------------------------------------------------------
              
          end // HBW doubly-constrained
      end // Iter 
      
      converged:
           
    end // purpose

    Return(1)
    
    quit:
      RunMacro("closeallviews", )
      ShowMessage("DChoice failed in purpose: "+Args.PNAME)
      Return(RunMacro("TCB Closing", ret_value, True) )
    
EndMacro



Macro "DC_Application" (Args,a)
    shared scen_data_dir

/*
 Each call to this macro runs a destination choice model for one trip purpose and auto group
 The market segments (mseg) are:
   1 - Zero Auto
   2 - One Auto
   3 - Two plus Autos
*/

     // Trip purpose name    
     pa_tab         = Args.[Household Production]
     tazpoly_info   = SplitPath(Args.[taz])
     pnam           = Args.PNAME  
     autoSuffNumber = a      
     coreName       = Args.coreName
                                             
     SetStatus(2,"DChoice for "+pnam,)
     
     // -------------------------------------------------------------------------------------------------
     // 1. Define temp and other files
     // -------------------------------------------------------------------------------------------------
     // Get the taz bin file 
     model_sed    = tazpoly_info[1]+ tazpoly_info[2] +tazpoly_info[3] + ".bin"
     
     // Temp files
     IZtemf = scen_data_dir + "outputs\\IntraZonal.mtx"
     tmatf  = scen_data_dir + "outputs\\Junk.mtx"
     capmf  = scen_data_dir + "outputs\\CappedDistance.mtx"
     cbdTF  = scen_data_dir + "outputs\\Dest_CBD_boolean.mtx"
     univTF = scen_data_dir + "outputs\\Dest_UNIV_boolean.mtx"
     distKF = scen_data_dir + "outputs\\Dest_KFactor.mtx"
     rivermf = scen_data_dir + "outputs\\RiverCrossingFlag.mtx"
     
     // Other files
     sedof  = scen_data_dir + "outputs\\model_sed_out.bin"                                               // SE data with size terms
     ptripf = scen_data_dir + "outputs\\"+pnam+"_PersonTrips.mtx"                                        // Output trip table 
     outtab = sedof
     outdic = scen_data_dir + "outputs\\model_sed_out.dcb"
     
     attr_out = scen_data_dir+"outputs\\CF_"+Args.PNAME+".txt"
     atmf     = scen_data_dir + "Reports\\"+ pnam + "_CountyTrips"+String(autoSuffNumber)+".mtx"        // trips summarized to county
     ptmf     = scen_data_dir + "Reports\\"+ pnam + "_PersonTripsMseg"+String(autoSuffNumber)+".csv"
     
     // Trace input (Optional input: if doesn't exist then trace is not done)
     traceProperties = scen_data_dir +"dc\\trace.properties"    
     
     // -------------------------------------------------------------------------------------------------
     // 2. TRACE sub-module                                                                 
     // -------------------------------------------------------------------------------------------------
     doesExist = GetFileInfo(traceProperties)
      // If file exists
      if doesExist != Null then do
        
         // Check if trace is truned on
         isTraceON = RunMacro("read properties",traceProperties,"trace")
         if (isTraceON = "true") then do
           
            // Get trace output filename
            outputFile = RunMacro("read properties",traceProperties,"DC_OutputFile")
            trace_out = scen_data_dir+"outputs\\"+pnam+String(autoSuffNumber)+"_"+outputFile
            
            // Get ij pairs to trace
            pa_pairs = RunMacro("read properties",traceProperties,"pa_taz")
            pairs = ParseString(pa_pairs,",")
            dim izones[pairs.length], jzones[pairs.length]
            for ij = 1 to pairs.length do 
              ijpair = ParseString(pairs[ij],"-")   
              izones[ij] = S2I(Trim(ijpair[1]))             // Get prodcution zones
              jzones[ij] = S2I(Trim(ijpair[2]))             // Get attraction zones
            end
            
            // Define file open mode type
            doesExist = GetFileInfo(trace_out)
            if doesExist != Null then openMode = "a+" else openMode = "w"
            
            // Write header line 
            fptr = OpenFile(trace_out, openMode)
            WriteLine(fptr, "=======================================================================") 
            WriteLine(fptr, "=======================================================================")
            WriteLine(fptr, "====== Destination Choice Model Trace =======" )
            date = GetDateAndTime()
            WriteLine(fptr, "=======================================================================")     
            WriteLine(fptr, date)
            WriteLine(fptr, "") 
            WriteLine(fptr, "Trace on pairs: "+ pa_pairs)
            WriteLine(fptr, "")
            CloseFile(fptr)
         end
      end
         
     // -------------------------------------------------------------------------------------------------
     // 3. MODEL COEFFICIENTS & INPUT PARAMETERS                                                                 
     // -------------------------------------------------------------------------------------------------
     //Number of Iterations for implementing Double Constraint DC Model
     // NumIter = Args.Iters
     
     // Open destination choice coefficients by market segment
     KPXMf   = Args.Coeff_DC_Size
     KPXMtab = OpenTable("KPXM", "FFB", {KPXMf})
     SetView(KPXMtab)
     
     // Read coefficients (a = auto sufficiency number)
     thislabel=pnam+String(autoSuffNumber)
     qry = "Select * where Purp='"+thislabel+"'"
     n = SelectByQuery("mypurp", "Several", qry,)   
     if(n<>1) then do
        ShowMessage(i2s(n)+" records for "+thislabel+" - fatal error")
        RunMacro("closeallviews", )
        return(0)
     end
     sset = KPXMtab+"|mypurp"
     arec = GetFirstRecord(sset,null)
     
     while (arec <> null) do
        // Size Terms  
        c_agri   = KPXMtab.c_agri
        c_manu   = KPXMtab.c_manu  
        c_trans  = KPXMtab.c_trans 
        c_ret    = KPXMtab.c_ret   
        c_office = KPXMtab.c_office
        c_hh     = KPXMtab.c_hh    
        c_k12    = KPXMtab.c_k12   
        c_col    = KPXMtab.c_col
        
        // DC Uitlity Coefficients
        c_lsum     = KPXMtab.c_lsum
        c_dist     = KPXMtab.c_dist
        c_distsq   = KPXMtab.c_distsq
        c_distcu   = KPXMtab.c_distcu
        c_distlog  = KPXMtab.c_distlog  
        
        // Distance K-Factors  
        c_kf01      = KPXMtab.c_KF01
        c_kf12      = KPXMtab.c_KF12
        c_kf23      = KPXMtab.c_KF23
        c_kf34      = KPXMtab.c_KF34
        c_kf45      = KPXMtab.c_KF45
        c_kf56      = KPXMtab.c_KF56
        c_kf67      = KPXMtab.c_KF67
        
         // Intrazonal Terms
        c_iz      = KPXMtab.c_iz
     
        // Market Segment Terms  
        c_dist_mseg= KPXMtab.c_dist_mseg
     
        // Distance cap
        distCap  = KPXMtab.distCap
     
        // Destination zone constants
        c_cbd    = KPXMtab.c_dest_cbd
        c_univ   = KPXMtab.c_dest_univ
        
        // River crossing flag
        c_bridge = KPXMtab.c_bridge
     
     
        arec = GetNextRecord(sset,null,null)
     end
     
     // ------------- Exclusive for NHB purposes ------------------------------  

     purpose_name = pnam
     
     SetView(KPXMtab)  
     if (purpose_name = "NHBW" or purpose_name = "NHBO") then do
     
         if (purpose_name = "NHBW") then other_NHB = "NHBO" else other_NHB = "NHBW"
           
         thislabel = other_NHB+String(autoSuffNumber)
         qry = "Select * where Purp='"+thislabel+"'"
         n = SelectByQuery("otherpurp", "Several", qry,)   
         if(n<>1) then do
            ShowMessage(i2s(n)+" records for "+thislabel+" - fatal error")
            RunMacro("closeallviews", )
            return(0)
         end
         sset = KPXMtab+"|otherpurp"
         arec = GetFirstRecord(sset,null)
         
         while (arec <> null) do
            other_c_agri   = KPXMtab.c_agri
            other_c_manu   = KPXMtab.c_manu  
            other_c_trans  = KPXMtab.c_trans 
            other_c_ret    = KPXMtab.c_ret   
            other_c_office = KPXMtab.c_office
            other_c_hh     = KPXMtab.c_hh    
            other_c_k12    = KPXMtab.c_k12   
            other_c_col    = KPXMtab.c_col
            arec = GetNextRecord(sset,null,null)
         end
     end // NHB trip purpose   
     CloseView(KPXMtab)    
   
     // ------------------ Trace module -----------------------------------
     // Write coeffcients and taz data to the trace file
     if (isTraceON = "true") then do
        fptr = OpenFile(trace_out, "a+")
        WriteLine(fptr, "====== Coefficients (used for NHB only)=======" )
        WriteLine(fptr,"Purpose  :" + pnam +" - Auto Group: " +String(autoSuffNumber) ) 
        WriteLine(fptr,"          " + purpose_name +"  -  "+ other_NHB) 
        WriteLine(fptr,"AGRI     :" + Format(c_agri,"0.0000")    + "     "+ Format(other_c_agri,"*0.0000")  ) 
        WriteLine(fptr,"MANU     :" + Format(c_manu,"0.0000")    +"      "+ Format(other_c_manu,"*0.0000")  ) 
        WriteLine(fptr,"TRANS    :" + Format(c_trans,"0.0000")   +"      "+ Format(other_c_trans,"*0.0000")  ) 
        WriteLine(fptr,"RET      :" + Format(c_ret,"0.0000")     +"      "+ Format(other_c_ret,"*0.0000")  )   
        WriteLine(fptr,"OFF      :" + Format(c_office,"0.0000")  +"      "+ Format(other_c_office,"*0.0000")  ) 
        WriteLine(fptr,"HH       :" + Format(c_hh,"0.0000")      +"      "+ Format(other_c_hh,"*0.0000")  )  
        WriteLine(fptr,"K12      :" + Format(c_k12,"0.0000")     +"      "+ Format(other_c_k12,"*0.0000")  )  
        WriteLine(fptr,"COLLEGE  :" + Format(c_col,"0.0000")     +"      "+ Format(other_c_col,"*0.0000")  ) 
        WriteLine(fptr, "")
        CloseFile(fptr)
     end  

     // -------------------------------------------------------------------------------------------------
     // 4. COMPUTE THE SIZE TERM                                                                
     // -------------------------------------------------------------------------------------------------
     // Merge SE Data and Prod/Attractions
     sedtab = OpenTable("Model SED", "FFB", {model_sed})
     CopyTableFiles(sedtab, "null", "null", "null", outtab, outdic)
     
     pa_vw = OpenTable("PATAB", "FFB", {pa_tab})
     if(pa_vw=null) then ShowMessage("Could not open PRODUCTIONS file")
     zdata_vw = JoinViews("jv", sedtab + ".ID", pa_vw + ".ID",)
     SetView(zdata_vw)
     
     // Get list of cbd zones
     cbd_qry = "Select * where Predict = 'CBD'"
     n = SelectByQuery("cbdzones", "Several",cbd_qry,) 
     
     // Get list of university zones
     univ_qry = "Select * where COLLEGE != 0"
     n = SelectByQuery("univzones", "Several",univ_qry,) 
     
     // Get a list of zones (north of river)
     north_qry = "Select * where NorthOfRiver = 1"
     n = SelectByQuery("northzones", "Several",north_qry,) 
     
     // Get a list of zones (south of river)
     south_qry = "Select * where NorthOfRiver = 0"
     n = SelectByQuery("southzones", "Several",south_qry,) 
     
     
     fields_array = GetFields(zdata_vw, "All")
     
     // Get employment array from joined view
     // - just choose a set of NAICS variables for the test - KDK 11/6/2012
     //              1           2            3           4           5           6          7             8 
     Emp_array = {"EMP_ARG", "EMP_MANU", "EMP_RET", "EMP_TRANS", "EMP_OFFICE", "HH10", "STUDENT_K12",  "COLLEGE"} 
     
     tazlab="["+sedtab+"].ID"
     emp=GetDataVectors(zdata_vw + "|",Emp_array,{{"Sort Order",{{tazlab,"A"}}}}) // read these & then consolidate NAICS to c_size members
     zones_vec = GetDataVector(zdata_vw + "|",tazlab,{{"Sort Order",{{tazlab,"A"}}}})
     
     // Get number of zones 
     zones = emp[1].length
     sizeVar = Vector(zones, "Float", {{"Constant",0},{"Row Based","True"}})
     
     c_size = {c_agri,  c_manu, c_ret, c_trans, c_office, c_hh, c_k12, c_col}
     
     for z = 1 to zones do
        for i=1 to emp.length do
          sizeVar[z] = sizeVar[z] + emp[i][z] * c_size[i]
          
           // ------------------ Trace module -----------------------------------
           if (isTraceON = "true") then do 
             // Write section title
             if(z=1 & i =1) then do 
                fptr = OpenFile(trace_out, "a+")
                WriteLine(fptr, "====== Sizeterm =======" )
                CloseFile(fptr)
              end
              // Loop by selected izones
              for ij = 1 to izones.length do
                // If curent zone is selected j zones
                if (zones_vec[z] = jzones[ij]) then do
                  // At the end of employment loop
                   if i = emp.length then do 
                      // Append the trace report file                
                      fptr = OpenFile(trace_out, "a+")
                      WriteLine(fptr,"Emp_Type: " + "Coefficient" + "  "+ "Emp_data["+String(zones_vec[z])+"]")
                      WriteLine(fptr,"AGR      :" +Format(c_size[ 1],"0.0000")  +"     "+ String(emp[ 1][z])) 
                      WriteLine(fptr,"MANU     :" +Format(c_size[ 2],"0.0000")  +"     "+ String(emp[ 2][z]))
                      WriteLine(fptr,"RET      :" +Format(c_size[ 3],"0.0000")  +"     "+ String(emp[ 3][z]))
                      WriteLine(fptr,"TRANS    :" +Format(c_size[ 4],"0.0000")  +"     "+ String(emp[ 4][z]))
                      WriteLine(fptr,"OFF      :" +Format(c_size[ 5],"0.0000")  +"     "+ String(emp[ 5][z]))
                      WriteLine(fptr,"HH       :" +Format(c_size[ 6],"0.0000")  +"     "+ String(emp[ 6][z]))
                      WriteLine(fptr,"K1       :" +Format(c_size[ 7],"0.0000")  +"     "+ String(emp[ 7][z]))
                      WriteLine(fptr,"COLLEGE  :" +Format(c_size[ 8],"0.0000")  +"     "+ String(emp[ 8][z]))
                      WriteLine(fptr,"Size Term:" +String(sizeVar[z]))
                      WriteLine(fptr, "")
                      CloseFile(fptr) 
                   end // end condition on last emp
                end // end condition on matched zone
              end // end selected pair loop
           end // end trace
          // ---------------------------------------------------------------------- 
        end  // end employment loop
     end  // end zone loop
     
     NewFlds = {{"SizeVar","real"}}
     sedout = OpenTable("Model SED", "FFB", {sedof})
     ok = RunMacro("TCB Add View Fields", {sedout, NewFlds})
     SetDataVector(sedout + "|", "SizeVar", sizeVar,)
     sizeVar = if sizeVar eq null then 0 else sizeVar
     
     // Scale the size terms to match productions total
     sizetot = VectorStatistic(sizeVar,"Sum",)
     
     // ---- Exclusive for NHB ------
     if (purpose_name = "NHBW" or purpose_name = "NHBO") then do
                     
        other_c_size = {other_c_agri,  other_c_manu, other_c_ret, other_c_trans, other_c_office, other_c_hh, other_c_k12, other_c_col}
        other_sizeVar = Vector(zones, "Float", {{"Constant",0},{"Row Based","True"}})
        
        for z = 1 to zones do
          for i=1 to emp.length do
            other_sizeVar[z] = other_sizeVar[z] + emp[i][z] * other_c_size[i]
           
            // ------------------ Trace module -----------------------------------
            if (isTraceON = "true") then do
               // Write section title 
               if(z=1 & i =1) then do 
                 fptr = OpenFile(trace_out, "a+")
                 WriteLine(fptr, "====== Sizeterm for other NHB =======" )
                 CloseFile(fptr)
               end
               // Loop by selected izones
               for ij = 1 to izones.length do
                 // If curent zone is selected j zones
                 if (zones_vec[z] = jzones[ij]) then do
                   // At the end of employment loop
                    if i = emp.length then do 
                       // Append the trace report file                
                       fptr = OpenFile(trace_out, "a+")
                       WriteLine(fptr,"Emp_Type: " + "Coefficient" + "  "+ "Emp_data["+String(zones_vec[z])+"]")
                       WriteLine(fptr,"AGRI      :"+Format(other_c_size[ 1],"0.0000")    +"      "+ String(emp[ 1][z])) 
                       WriteLine(fptr,"MANU      :"+Format(other_c_size[ 2],"0.0000")    +"      "+ String(emp[ 2][z]))
                       WriteLine(fptr,"TRANS     :"+Format(other_c_size[ 3],"0.0000")    +"      "+ String(emp[ 3][z]))
                       WriteLine(fptr,"RET       :"+Format(other_c_size[ 4],"0.0000")    +"      "+ String(emp[ 4][z]))
                       WriteLine(fptr,"OFF       :"+Format(other_c_size[ 5],"0.0000")    +"      "+ String(emp[ 5][z]))
                       WriteLine(fptr,"HH        :"+Format(other_c_size[ 6],"0.0000")    +"      "+ String(emp[ 6][z]))
                       WriteLine(fptr,"K12       :"+Format(other_c_size[ 7],"0.0000")    +"      "+ String(emp[ 7][z]))
                       WriteLine(fptr,"COLLEGE   :"+Format(other_c_size[ 8],"0.0000")    +"      "+ String(emp[ 8][z]))
                       WriteLine(fptr,"Other NHB Size Term : "+String(other_sizeVar[z]))
                       WriteLine(fptr, "")
                       CloseFile(fptr)  
                    end // end condition on last emp
                 end // end condition on matched zone
               end // end selected pair loop
            end // end trace
           // ----------------------------------------------------------------------  
           end
        end
        
        NewFlds = {{"otherSizeVar","real"}}
        sedout = OpenTable("Model SED", "FFB", {sedof})
        ok = RunMacro("TCB Add View Fields", {sedout, NewFlds})
        SetDataVector(sedout + "|", "otherSizeVar", other_sizeVar,)
        other_sizetot = VectorStatistic(other_sizeVar,"Sum",)       
     end 
                     

     // -------------------------------------------------------------------------------------------------
     // 5. OPEN ALL IMPEDANCE MATRICES                                                             
     // -------------------------------------------------------------------------------------------------
     // Drive alone distance
     hwymat = OpenMatrix(Args.[DA Skims],)
     matidxnames=GetMatrixIndexNames(hwymat)
     // Update zones index
     for i=1 to matidxnames[1].length do
       if matidxnames[1][i]="Zones" then DeleteMatrixIndex(hwymat, "Zones")
     end
     index = CreateMatrixIndex("Zones",hwymat,"Both", zdata_vw + "|",tazlab,tazlab)
     
     // Created NON-TOLL DISTANCE core from old Length core, should be correct
     distmc = CreateMatrixCurrency(hwymat,"Length","Zones","Zones",)                 
     distmc := nz(distmc)
      
     // Read destination choice logsums
     logsum = Args.Logsums
     lsmat = OpenMatrix(logsum,)
     // Update zones index
     matidxnames=GetMatrixIndexNames(lsmat)
     for i=1 to matidxnames[1].length do
       if matidxnames[1][i]="Zones" then DeleteMatrixIndex(lsmat, "Zones")
     end
     index = CreateMatrixIndex("Zones",lsmat,"Both", zdata_vw + "|",tazlab,tazlab)
     lsmc = CreateMatrixCurrency(lsmat,coreName,"Zones","Zones",)
     lsmc := nz(lsmc)

      
     // Create capped distance matrix
     opts = null
     opts.[File Name] = capmf
     opts.Label = "Distance"
     opts.[Tables] = {"Matrix1"}
     capmat = CopyMatrixStructure({distmc},opts)
     // Update zones index
     matidxnames=GetMatrixIndexNames(capmat)
     for i=1 to matidxnames[1].length do
       if matidxnames[1][i]="Zones" then DeleteMatrixIndex(capmat, "Zones")
     end
     index = CreateMatrixIndex("Zones",capmat,"Both", zdata_vw + "|",tazlab,tazlab)
     capdistmc = CreateMatrixCurrency(capmat, "Matrix1", "Zones", "Zones",)
     capdistmc := min(distmc,distCap)


     // Create distance K-Factor indicator matrix
     opts = null
     opts.[File Name] = distKF
     opts.Label = "Distance"
     opts.[Tables] = {"kf01","kf12","kf23","kf34","kf45","kf56","kf67"}
     kfmat = CopyMatrixStructure({distmc},opts)
     // Update zones index
     matidxnames=GetMatrixIndexNames(kfmat)
     for i=1 to matidxnames[1].length do
       if matidxnames[1][i]="Zones" then DeleteMatrixIndex(kfmat, "Zones")
     end
     index = CreateMatrixIndex("Zones",kfmat,"Both", zdata_vw + "|",tazlab,tazlab)
     mc_kf01 = CreateMatrixCurrency(kfmat, "kf01", "Zones", "Zones",)
     mc_kf12 = CreateMatrixCurrency(kfmat, "kf12", "Zones", "Zones",)
     mc_kf23 = CreateMatrixCurrency(kfmat, "kf23", "Zones", "Zones",)
     mc_kf34 = CreateMatrixCurrency(kfmat, "kf34", "Zones", "Zones",)
     mc_kf45 = CreateMatrixCurrency(kfmat, "kf45", "Zones", "Zones",)
     mc_kf56 = CreateMatrixCurrency(kfmat, "kf56", "Zones", "Zones",)
     mc_kf67 = CreateMatrixCurrency(kfmat, "kf67", "Zones", "Zones",)
     // Flag currencies
     mc_kf01 := if (distmc > 0 & distmc <= 1) then 1 else 0
     mc_kf12 := if (distmc > 1 & distmc <= 2) then 1 else 0
     mc_kf23 := if (distmc > 2 & distmc <= 3) then 1 else 0
     mc_kf34 := if (distmc > 3 & distmc <= 4) then 1 else 0
     mc_kf45 := if (distmc > 4 & distmc <= 5) then 1 else 0
     mc_kf56 := if (distmc > 5 & distmc <= 6) then 1 else 0
     mc_kf67 := if (distmc > 6 & distmc <= 7) then 1 else 0
      

     // Create river-crossing matrix
     opts = null
     opts.[File Name] = rivermf
     opts.Label = "Distance"
     opts.[Tables] = {"FlagRiverCrossings"}
     rivermat = CopyMatrixStructure({distmc},opts)
     // Update zones index
     matidxnames=GetMatrixIndexNames(rivermat)
     for i=1 to matidxnames[1].length do
       if matidxnames[1][i]="Zones" then DeleteMatrixIndex(rivermat, "Zones")
     end
     index   = CreateMatrixIndex("North",rivermat,"Both", zdata_vw + "|northzones",tazlab,tazlab)
     index   = CreateMatrixIndex("South",rivermat,"Both", zdata_vw + "|southzones",tazlab,tazlab)
     // Fill in flags for river crossings
     rivermc = CreateMatrixCurrency(rivermat, "FlagRiverCrossings", "North", "South",)
     rivermc := 1 
     rivermc = CreateMatrixCurrency(rivermat, "FlagRiverCrossings", "South", "North",)
     rivermc := 1
     // Create all zone index 
     index   = CreateMatrixIndex("Zones",rivermat,"Both", zdata_vw + "|",tazlab,tazlab)
     rivermc = CreateMatrixCurrency(rivermat, "FlagRiverCrossings", "Zones", "Zones",)
     rivermc := nz(rivermc)

      
     // Create the intrazonal indicator matrix  
     opts = null
     opts.[File Name] = IZtemf
     opts.Label = "IZ"
     opts.[Tables] = {"Matrix1"}
     izmat = CopyMatrixStructure({distmc},opts)
     // Update zones index
     matidxnames=GetMatrixIndexNames(izmat)
     for i=1 to matidxnames[1].length do
       if matidxnames[1][i]="Zones" then DeleteMatrixIndex(izmat, "Zones")
     end
     index = CreateMatrixIndex("Zones",izmat,"Both", zdata_vw + "|",tazlab,tazlab)
     izmc = CreateMatrixCurrency(izmat, "Matrix1", "Zones", "Zones",)
     izmc := 0
     opts = null
     opts.[Diagonal] = "True"
     FillMatrix(izmc,,, {"Add", 1}, opts)


     // Create CBD indicator matrix  
     opts = null
     opts.[File Name] = cbdTF
     opts.Label = "CBD"
     opts.[Tables] = {"Matrix1"}
     cbdmat = CopyMatrixStructure({distmc},opts)
     // Add cbd zone index 
     index = CreateMatrixIndex("cbd",cbdmat,"Column", zdata_vw + "|cbdzones",tazlab,tazlab)
     // Update zones index
     matidxnames=GetMatrixIndexNames(cbdmat)
     for i=1 to matidxnames[1].length do
       if matidxnames[1][i]="Zones" then DeleteMatrixIndex(cbdmat, "Zones")
     end
     index = CreateMatrixIndex("Zones",cbdmat,"Both", zdata_vw + "|",tazlab,tazlab)
     // Fill cbd (destination) zones with 1
     cbdmc = CreateMatrixCurrency(cbdmat, "Matrix1", "Zones", "cbd",)
     cbdmc := 0
     opts = null
     opts.[All] = "True"
     FillMatrix(cbdmc,,, {"Add", 1}, opts)
     cbdmc = CreateMatrixCurrency(cbdmat, "Matrix1", "Zones", "Zones",)


     // Create university indicator matrix  
     opts = null
     opts.[File Name] = univTF
     opts.Label = "Univ"
     opts.[Tables] = {"Matrix1"}
     univmat = CopyMatrixStructure({distmc},opts)
     // Add cbd zone index 
     index = CreateMatrixIndex("univ",univmat,"Column", zdata_vw + "|univzones",tazlab,tazlab)
     // Update zones index
     matidxnames=GetMatrixIndexNames(univmat)
     for i=1 to matidxnames[1].length do
       if matidxnames[1][i]="Zones" then DeleteMatrixIndex(univmat, "Zones")
     end
     index = CreateMatrixIndex("Zones",univmat,"Both", zdata_vw + "|",tazlab,tazlab)
     // Fill university zones(destination)  with 1
     univmc = CreateMatrixCurrency(univmat, "Matrix1", "Zones", "univ",)
     univmc := 0
     opts = null
     opts.[All] = "True"
     FillMatrix(univmc,,, {"Add", 1}, opts)
     univmc = CreateMatrixCurrency(univmat, "Matrix1", "Zones", "Zones",)
 
     // -------------------------------------------------------------------------------------------------
     // 6.  APPLY DESTINATION CHOICE MODEL                                                       
     // -------------------------------------------------------------------------------------------------
     // For NHB trips, scale attractions and replace productions with attractions
     if (purpose_name = "NHBW" or purpose_name = "NHBO") then do 
        prodlabel_NHBW ="[NHBW" + String(autoSuffNumber) + "]"
        prodlabel_NHBO ="[NHBO" + String(autoSuffNumber) + "]"  
        production_NHBW = GetDataVector(zdata_vw + "|",prodlabel_NHBW,{{"Sort Order",{{tazlab,"A"}}}})
        production_NHBO = GetDataVector(zdata_vw + "|",prodlabel_NHBO,{{"Sort Order",{{tazlab,"A"}}}}) 
        productions = production_NHBW + production_NHBO
        trace_productions = productions
        trace_old_sizeVar = sizeVar
     
        // Replace productions with scaled sizeVar 
        productions = sizeVar * VectorStatistic(productions,"Sum",)/(sizetot + other_sizetot)
     
        // Scale size term
        if(purpose_name = "NHBW") then productions_pur = production_NHBW
        if(purpose_name = "NHBO") then productions_pur = production_NHBO       
        sizeVar = sizeVar*VectorStatistic(productions_pur,"Sum",)/sizetot
         
        // ------------------ Trace module -----------------------------------
        if (isTraceON = "true") then do
           // Loop by selected izones
           for ij = 1 to izones.length do
               // Write section title 
               if(ij =1) then do 
                 fptr = OpenFile(trace_out, "a+")
                 WriteLine(fptr, "====== Trip Productions & Attractions =======" )
                 CloseFile(fptr)
               end
              // Loop by zones
              for z = 1 to zones_vec.length do
                 // If curent zone is selected i zones
                 if (zones_vec[z] = izones[ij]) then do
                    // Writes productions
                    fptr = OpenFile(trace_out, "a+")
                    WriteLine(fptr,"P-TAZ              : "+ String(zones_vec[z]))
                    WriteLine(fptr,"Productions NHBW   : " + String(production_NHBW[z]))
                    WriteLine(fptr,"Productions NHBO   : " + String(production_NHBO[z]))
                    WriteLine(fptr,"Regional prods NHBW: " + String(VectorStatistic(production_NHBW,"Sum",)))
                    WriteLine(fptr,"Regional prods NHBO: " + String(VectorStatistic(production_NHBO,"Sum",)))
                    WriteLine(fptr,"Regional prods NHB : " + String(VectorStatistic(trace_productions,"Sum",)))
                    WriteLine(fptr,"Regional attrs "+purpose_name +" : " + String(sizetot))
                    WriteLine(fptr,"Regional attrs "+other_NHB    +" : " + String(other_sizetot))
                    WriteLine(fptr,"Regional attrs NHB  : " + String(sizetot + other_sizetot))
                    WriteLine(fptr,"Scale by           : " + String(VectorStatistic(trace_productions,"Sum",)/(sizetot + other_sizetot))) 
                    WriteLine(fptr,"P-Zone Size Term "+purpose_name +" : " + String(trace_old_sizeVar[z])) 
                    WriteLine(fptr,"P-Zone Scaled Size Term "+purpose_name +" : " + String(sizeVar[z]))
                    WriteLine(fptr,"Scaled prods "+purpose_name       +" : " + String(productions[z]))
                    CloseFile(fptr)               
                 end // end condition on i zone selection 
              end // end i zone 
              
              for z = 1 to zones_vec.length do
                 // If curent zone is selected i zones
                 if (zones_vec[z] = jzones[ij]) then do             
                    // Writes productions
                    fptr = OpenFile(trace_out, "a+")
                    WriteLine(fptr,"A-TAZ     : " + String(zones_vec[z])) 
                    WriteLine(fptr,"A-Zone Size Term "+purpose_name +" : " + String(trace_old_sizeVar[z])) 
                    WriteLine(fptr,"A-Zone Scaled Size Term "+purpose_name +" : " + String(sizeVar[z]))
                    WriteLine(fptr, "")
                    CloseFile(fptr)     
                end // end condition on j zone selection 
              end // end j zone 
                                                 
           end // end selected zone loop
        end // end trace
        // ------------------------------------------------------------------ 
     end // end NHB purpose condition
     
        
     // Scale size terms by productions
     if (purpose_name <> "NHBW" & purpose_name <> "NHBO") then do 
        prodlabels="[" + pnam + String(autoSuffNumber) + "]"
        productions = GetDataVector(zdata_vw + "|",prodlabels,{{"Sort Order",{{tazlab,"A"}}}})
        productions.ColumnBased = "True"
        productions = if productions < 0 then 0 else productions
        productions = if productions=null then 0 else productions
        trace_old_sizeVar = sizeVar 
        sizeVar = sizeVar*VectorStatistic(productions,"Sum",)/sizetot
       
       // ------------------ Trace module -----------------------------------
        if (isTraceON = "true") then do
           // Loop by selected izones
           for ij = 1 to izones.length do 
              // Write section title 
              if(ij =1) then do 
                fptr = OpenFile(trace_out, "a+")
                WriteLine(fptr, "====== Trip Productions & Attractions =======" )
                CloseFile(fptr)
              end 
              // Loop by zones
              for z = 1 to zones_vec.length do
                 // If curent zone is selected zones
                 if (zones_vec[z] = izones[ij]) then do
                    // Writes scaled size term
                    fptr = OpenFile(trace_out, "a+")
                    WriteLine(fptr,"P-TAZ         :"+ String(zones_vec[z]))
                    WriteLine(fptr,"Productions   :" + String(productions[z]))
                    WriteLine(fptr,"Regional prods:" + String(VectorStatistic(productions,"Sum",)))
                    WriteLine(fptr,"Regional attr :" + String(sizetot))
                    WriteLine(fptr,"Scale by      :" + String(VectorStatistic(productions,"Sum",)/sizetot)) 
                    CloseFile(fptr)
                 end // end condition on zone selection
              end  // zone loop 
              
              for z = 1 to zones_vec.length do
                 // If curent zone is selected i zones
                 if (zones_vec[z] = jzones[ij]) then do             
                    // Writes productions
                    fptr = OpenFile(trace_out, "a+")
                    WriteLine(fptr,"A-TAZ     : " + String(zones_vec[z])) 
                    WriteLine(fptr,"A-Zone Size Term "+purpose_name +" : " + String(trace_old_sizeVar[z])) 
                    WriteLine(fptr,"A-Zone Scaled Size Term "+purpose_name +" : " + String(sizeVar[z]))
                    WriteLine(fptr, "")
                    CloseFile(fptr)     
                end // end condition on j zone selection 
              end // end j zone 
           end // end selected zone loop
        end // end trace
        // ------------------------------------------------------------------      
     end   // end purpose condition
     
     // Create a matrix to store intermediate calculations
     opts = null
     opts.[File Name] = tmatf
     opts.Label = "Junk"
     opts.[Tables] = {"Common","Util","Util_CF","ExpUtil","Prob"}
     tempmat = CopyMatrixStructure({distmc,distmc,distmc,distmc,distmc},opts)
     matidxnames=GetMatrixIndexNames(tempmat)
     for i=1 to matidxnames[1].length do
       if matidxnames[1][i]="Zones" then DeleteMatrixIndex(tempmat, "Zones")
     end
     index = CreateMatrixIndex("Zones",tempmat,"Both", zdata_vw + "|",tazlab,tazlab)
     commonmc = CreateMatrixCurrency(tempmat, "Common", "Zones", "Zones",)
     
     // Create an output matrix to store trip tables (do it only once)
     if autoSuffNumber = 1 then do 
        if FileCheckUsage({ptripf},) then do
          ShowMessage("File already in use.")
        end
        opts = null
        opts.[File Name] = ptripf
        opts.Label    = "Person Trips"
        opts.[Tables] = {pnam + String(autoSuffNumber)}       
        permat = CopyMatrixStructure({distmc},opts) 
        matidxnames=GetMatrixIndexNames(permat)
        for i=1 to matidxnames[1].length do
          if matidxnames[1][i]="Zones" then DeleteMatrixIndex(permat, "Zones")
          if matidxnames[2][i]="Zones" then DeleteMatrixIndex(permat, "Zones")
        end
        index = CreateMatrixIndex("Zones",permat,"Both", zdata_vw + "|",tazlab,tazlab)
      end else do 
        permat = OpenMatrix(ptripf,)
        label  = pnam + String(autoSuffNumber)
        AddMatrixCore(permat, label)
     end
     label  = pnam + String(autoSuffNumber)
     msegmc = CreateMatrixCurrency(permat, label, "Zones", "Zones",)
     msegmc := 0.0

     // Compute the probability of
     // selection and apply to the vector of productions
     utilmc     = CreateMatrixCurrency(tempmat, "Util", "Zones", "Zones",)
     util_CF_mc = CreateMatrixCurrency(tempmat, "Util_CF", "Zones", "Zones",)
     expmc      = CreateMatrixCurrency(tempmat, "ExpUtil", "Zones", "Zones",)
     prbmc      = CreateMatrixCurrency(tempmat, "Prob", "Zones", "Zones",)

     // Read shadow price 
     outfile = OpenFile(attr_out,"r")
     CF_arr = ReadArray(outfile)
     for arr = 1 to CF_arr.length do
        CF_arr[arr] = Value(CF_arr[arr])
     end
     CF = A2V(CF_arr)
     CloseFile(outfile)

     // Compute the common utility
     commonmc := 0
     commonmc :=   c_dist      * capdistmc            +    // Distance
                   c_distsq    * Pow(capdistmc,2)     +    // Distance Square
                   c_distcu    * Pow(capdistmc,3)     +    // Distance Cube
                   c_distlog   * log(capdistmc)       +    // Distance Log
                   c_iz        * izmc                 +    // Intrazonal Constant
                   c_cbd       * nz(cbdmc)            +    // CBD constant
                   c_univ      * nz(univmc)           +    // University Constant
                   c_kf01      * mc_kf01              +    // K-Factor 0-1
                   c_kf12      * mc_kf12              +    // K-Factor 1-2
                   c_kf23      * mc_kf23              +    // K-Factor 2-3
                   c_kf34      * mc_kf34              +    // K-Factor 3-4
                   c_kf45      * mc_kf45              +    // K-Factor 4-5
                   c_kf56      * mc_kf56              +    // K-Factor 5-6
                   c_kf67      * mc_kf67              +    // K-Factor 6-7
                   c_bridge    * rivermc                   // Bridge crossing penalty
     
     utilmc  := 0.0
     utilmc  := commonmc + c_dist_mseg * capdistmc + c_lsum * lsmc
     utilmc  := if(sizeVar gt 0) then utilmc + log(sizeVar) else 0.0    
     util_CF_mc := if(sizeVar gt 0) then utilmc + CF else 0.0
     
     // Compute probability
     expmc   := if(sizeVar gt 0) then exp(util_CF_mc) else 0.0
     rowsum   = GetMatrixVector(expmc, {{"Marginal","Row Sum"}})
     productions.ColumnBased = "True"
     prbmc   := if(rowsum gt 0.0) then expmc/rowsum else 0.0
     
     // Compute trips
     tripsmc = CreateMatrixCurrency(permat, pnam + String(autoSuffNumber), "Zones", "Zones",)
     tripsmc := 0.0
     tripsmc := prbmc * productions * 100
     RoundMatrix(tripsmc,)  //bucket rounding: rounds only to integers
     tripsmc := if(tripsmc eq null) then 0 else tripsmc/100
     
     // ------------------ Trace module -----------------------------------
     if (isTraceON = "true") then do
        // Loop by selected izones
        for ij = 1 to izones.length do
          fptr = OpenFile(trace_out, "a+")
          
          for z = 1 to zones_vec.length do
             // If curent zone is selected j zones
             if (zones_vec[z] = jzones[ij]) then do 
               trace_sizeTerm = sizeVar[z]
               trace_shadowPrice = CF[z]
               trace_rowsum  = rowsum[z]
             end
          end
                   
          // Get matrix values for all IJ pairs
          trace_capdist    = GetMatrixValue(capdistmc,String(izones[ij]), String(jzones[ij]))
          trace_intrazonal = GetMatrixValue(izmc     ,String(izones[ij]), String(jzones[ij]))
          trace_cbd        = GetMatrixValue(cbdmc    ,String(izones[ij]), String(jzones[ij]))
          trace_univ       = GetMatrixValue(univmc   ,String(izones[ij]), String(jzones[ij]))
          trace_kf01       = GetMatrixValue(mc_kf01  ,String(izones[ij]), String(jzones[ij])) 
          trace_kf12       = GetMatrixValue(mc_kf12  ,String(izones[ij]), String(jzones[ij])) 
          trace_kf23       = GetMatrixValue(mc_kf23  ,String(izones[ij]), String(jzones[ij])) 
          trace_kf34       = GetMatrixValue(mc_kf34  ,String(izones[ij]), String(jzones[ij])) 
          trace_kf45       = GetMatrixValue(mc_kf45  ,String(izones[ij]), String(jzones[ij])) 
          trace_kf56       = GetMatrixValue(mc_kf56  ,String(izones[ij]), String(jzones[ij])) 
          trace_kf67       = GetMatrixValue(mc_kf67  ,String(izones[ij]), String(jzones[ij]))
          trace_river      = GetMatrixValue(rivermc  ,String(izones[ij]), String(jzones[ij])) 
          trace_common     = GetMatrixValue(commonmc ,String(izones[ij]), String(jzones[ij]))
          trace_logsum     = GetMatrixValue(lsmc     ,String(izones[ij]), String(jzones[ij]))
          trace_util       = GetMatrixValue(utilmc   ,String(izones[ij]), String(jzones[ij]))
          trace_util_cf    = GetMatrixValue(util_CF_mc ,String(izones[ij]), String(jzones[ij]))
          trace_expmc      = GetMatrixValue(expmc,String(izones[ij]), String(jzones[ij]))
          trace_prob       = GetMatrixValue(prbmc,String(izones[ij]), String(jzones[ij]))
          trace_tripsmc    = GetMatrixValue(tripsmc,String(izones[ij]), String(jzones[ij]))             
          trace_capdist_sq = Pow(trace_capdist,2)
          trace_capdist_cu = Pow(trace_capdist,3)
          trace_capdist_ln = log(trace_capdist)   
                                
          // Writes matrix values for the selected zones
          WriteLine(fptr, "====== DC Utilitites =======" )
          WriteLine(fptr,"PA-TAZ         : " + String(izones[ij])+" - "+String(jzones[ij]))
          WriteLine(fptr,"Type           :  Coefficient    matrix-value     product  ")
          WriteLine(fptr,"Distance       : "+Format(c_dist     ,"*0.0000")+"        "+Format(trace_capdist   ,"*0.0000")+"      "+ Format(c_dist*trace_capdist      , "*0.0000")) 
          WriteLine(fptr,"Distance - Sqr : "+Format(c_distsq   ,"*0.0000")+"        "+Format(trace_capdist_sq,"*0.0000")+"      "+ Format(c_distsq*trace_capdist_sq , "*0.0000"))
          WriteLine(fptr,"Distance - Cube: "+Format(c_distcu   ,"*0.0000")+"        "+Format(trace_capdist_cu,"*0.0000")+"      "+ Format(c_distcu*trace_capdist_cu , "*0.0000")) 
          WriteLine(fptr,"Distance - Log : "+Format(c_distlog  ,"*0.0000")+"        "+Format(trace_capdist_ln,"*0.0000")+"      "+ Format(c_distlog*trace_capdist_ln, "*0.0000"))          
          WriteLine(fptr,"Intrazonal     : "+Format(c_iz       ,"*0.0000")+"        "+Format(trace_intrazonal,"*0.0000")+"      "+ Format(c_iz*trace_intrazonal     , "*0.0000"))
          WriteLine(fptr,"CBD            : "+Format(c_cbd      ,"*0.0000")+"        "+Format(trace_cbd       ,"*0.0000")+"      "+ Format(c_cbd*trace_cbd           , "*0.0000")) 
          WriteLine(fptr,"University     : "+Format(c_univ     ,"*0.0000")+"        "+Format(trace_univ      ,"*0.0000")+"      "+ Format(c_univ*trace_univ         , "*0.0000"))
          WriteLine(fptr,"K-Factor 0-1   : "+Format(c_kf01     ,"*0.0000")+"        "+Format(trace_kf01      ,"*0.0000")+"      "+ Format(c_kf01*trace_kf01         , "*0.0000")) 
          WriteLine(fptr,"K-Factor 1-2   : "+Format(c_kf12     ,"*0.0000")+"        "+Format(trace_kf12      ,"*0.0000")+"      "+ Format(c_kf12*trace_kf12         , "*0.0000")) 
          WriteLine(fptr,"K-Factor 2-3   : "+Format(c_kf23     ,"*0.0000")+"        "+Format(trace_kf23      ,"*0.0000")+"      "+ Format(c_kf23*trace_kf23         , "*0.0000")) 
          WriteLine(fptr,"K-Factor 3-4   : "+Format(c_kf34     ,"*0.0000")+"        "+Format(trace_kf34      ,"*0.0000")+"      "+ Format(c_kf34*trace_kf34         , "*0.0000")) 
          WriteLine(fptr,"K-Factor 4-5   : "+Format(c_kf45     ,"*0.0000")+"        "+Format(trace_kf45      ,"*0.0000")+"      "+ Format(c_kf45*trace_kf45         , "*0.0000")) 
          WriteLine(fptr,"K-Factor 5-6   : "+Format(c_kf56     ,"*0.0000")+"        "+Format(trace_kf56      ,"*0.0000")+"      "+ Format(c_kf56*trace_kf56         , "*0.0000")) 
          WriteLine(fptr,"K-Factor 6-7   : "+Format(c_kf67     ,"*0.0000")+"        "+Format(trace_kf67      ,"*0.0000")+"      "+ Format(c_kf67*trace_kf67         , "*0.0000")) 
          WriteLine(fptr,"River Crossing : "+Format(c_bridge   ,"*0.0000")+"        "+Format(trace_river     ,"*0.0000")+"      "+ Format(c_bridge*trace_river      , "*0.0000")) 
          WriteLine(fptr,"Common-Utility : "+Format(trace_common, "*0.0000")) 
          WriteLine(fptr,"Logsum         : "+Format(c_lsum     ,"*0.0000")+"         "+Format(trace_logsum    ,"*0.0000")+"       "+ Format(c_lsum*trace_logsum       , "*0.0000"))
          WriteLine(fptr,"Dist_MSEG      : "+Format(c_dist_mseg,"*0.0000")+"         "+Format(trace_capdist ,"*0.0000")+" "+ Format(c_dist_mseg*trace_capdist , "*0.0000"))
          WriteLine(fptr,"log(sizeterm)  : "+Format(log(trace_sizeTerm), "*0.0000")) 
          WriteLine(fptr,"Utility        : "+Format(trace_util  , "*0.0000"))
          WriteLine(fptr,"Shadow Price   : "+Format(trace_shadowPrice, "*0.0000"))
          WriteLine(fptr,"Final Utility  : "+Format(trace_util  , "*0.0000"))
          WriteLine(fptr, "")
          WriteLine(fptr, "====== DC Probability =======" )
          WriteLine(fptr,"PA-TAZ           : "+String(izones[ij])+" - "+String(jzones[ij]))
          WriteLine(fptr,"exp(Utility)     : "+Format(trace_expmc, "*0.0000")) 
          WriteLine(fptr,"RowSum(exp(Util)): "+Format(trace_rowsum, "*0.0000"))
          WriteLine(fptr,"Probability      : "+Format(trace_prob, "*0.0000")) 
          WriteLine(fptr,"trips            : "+Format(trace_tripsmc  , "*0.0000"))
          WriteLine(fptr, "")
          WriteLine(fptr, "")
          CloseFile(fptr)
        end // end selected zone loop
     end // end trace
     // ------------------------------------------------------------------    

     // save separate matrices by income group and aggregate them
     msegmc := tripsmc
     
     // -------------------------------------------------------------------------------------------------
     // 7. REPORTS & SUMMARY DATA                                                              
     // -------------------------------------------------------------------------------------------------
     // Open TAZ geography file
     geo_vw = OpenTable("TAZ Indy", "FFB", {model_sed})
     
     // Aggregate total person trips to counties
     label="Aggregated Trips Inc " + String(autoSuffNumber)
     Opts = null
     Opts.Input.[Matrix Currency] = msegmc
     Opts.Input.[Aggregation View] = geo_vw
     
     // Change here to summarize on some other attributes in the TAZ file
     Opts.Global.[Row Names] = {geo_vw+".TAZ", geo_vw+".COUNTYFP10"}
     Opts.Global.[Column Names] = {geo_vw+".TAZ", geo_vw+".COUNTYFP10"}
     Opts.Output.[Aggregated Matrix].Label = label
     
     Opts.Output.[Aggregated Matrix].[File Name] = atmf
     ret_value = RunMacro("TCB Run Operation", "Aggregate Matrix", Opts)
     
     // Export person trips to CSV for trip length frequency calculations
     index = GetMatrixIndex(permat)
     arr = GetMatrixIndexIDs(permat, index[2]) // Get the column IDs
     for i = 1 to arr.length do
        arr[i] = i2s(arr[i]) // Convert all array elements to string.
     end
     ExportMatrix(msegmc, arr, "Rows", "CSV", ptmf, )
     
     // Close all matrices
     mtxs = GetMatrices()
     if mtxs <> null then do
       handles = mtxs[1]
       for i = 1 to handles.length do
         handles[i] = null
       end
     end 
     
     // Delete interim files
 /*    DeleteFile(IZtemf)
     DeleteFile(tmatf)
     DeleteFile(capmf)
     DeleteFile(cbdTF)
     DeleteFile(univTF)
*/
     RunMacro("closeallviews", )
     Return(1)

endMacro





Macro "closeallviews"
// This loop closes all views:
vws = GetViewNames()
for i = 1 to vws.length do
     CloseView(vws[i])
     end
EndMacro



// Reads property file
Macro "read properties" (filename,parameter)
  // Open file
     fptr = OpenFile(filename,"r")
     
  // Loop over lines till end-of-file  
     while !FileAtEOF(fptr) do
     // Read line
       line = Trim(ReadLine(fptr))
     // Parse string on "equals" sign  
        coeff_line = ParseString(line,"=")
     // Find keyword 
        if coeff_line.length > 0 and Trim(coeff_line[1]) = parameter then do
        // If found, get the value
           coeff = trim(coeff_line[2])
       end  // end search condition
     end // end while loop 
  
  // Close the file
     CloseFile(fptr)
     
  // Return the value for the keyword   
     return(coeff)
EndMacro




