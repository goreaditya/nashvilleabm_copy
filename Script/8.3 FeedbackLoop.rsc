/*
   Update Travel Time in the network
*/
Macro "UpdateTravelTimes" (Args)
	shared Scen_Dir, loop
	starttime = RunMacro("RuntimeLog", {"Update Travel Times ", null})
	RunMacro("HwycadLog", {"8.3 FeedbackLoop.rsc", "  ****** Update Travel Times ****** "})

  // Open Highway network
  hwy_db = Args.[hwy db]	
  network_file = Args.[Network File] 
  {node_lyr,link_lyr} = RunMacro("TCB Add DB Layers", hwy_db,,)
  
  periods = {"AM","MD","PM","OP"}
  
  // Loop by periods and update
  for p = 1 to periods.length do
     ODMAT_File   = Scen_Dir+ "outputs\\"+periods[p]+"OD.mtx"
     asgn_binFile = Scen_Dir+ "outputs\\Assignment_"+periods[p]+".bin"
     
     // Select only these links     
     asgn_vw = OpenTable("Assignment Result","FFB",{asgn_binFile,})
     join_vw = JoinViews("jv", link_lyr+".ID", asgn_vw+".ID1",)
     SetView(join_vw)
     fields_array = GetFields(join_vw, "All")
     n = SelectByQuery("AssignedLinks", "Several", "Select * where Lanes>0 and Assignment_LOC=1",)
     
     // Get assignment traveltimes 
     ab_time = GetDataVector(join_vw+"|AssignedLinks", "AB_Time",)
     ba_time = GetDataVector(join_vw+"|AssignedLinks", "BA_Time",)
     
     // Set travel time in the network
     SetDataVector(join_vw+"|AssignedLinks", "time_"+periods[p]+"_AB", ab_time,) 
     SetDataVector(join_vw+"|AssignedLinks", "time_"+periods[p]+"_BA", ba_time,) 

    CloseView(join_vw)
    CloseView(asgn_vw)
    
    //update the network file
    Opts = null
    Opts.Input.Database = hwy_db
    Opts.Input.Network = network_file
    Opts.Input.[Link Set] = {hwy_db+"|"+link_lyr, link_lyr}
    Opts.Global.[Fields Indices] = "time_"+periods[p]+"_*"
    Opts.Global.Options.[Link Fields] = { {link_lyr+".time_"+periods[p]+"_AB",link_lyr+".time_"+periods[p]+"_BA" } }
    Opts.Global.Options.Constants = {1}
    ret_value = RunMacro("TCB Run Operation",  "Update Network Field", Opts) 
    if !ret_value then goto quit         
    
    // Save outputs as csv with loop number prefix
    RunMacro("Copy Hwy Outfile",asgn_binFile,loop)
    RunMacro("Compute Rmse",asgn_binFile)
    RunMacro ("Convergence")
    RunMacro("Copy mat files",ODMAT_File, loop) 
  end     

	endtime = RunMacro("RuntimeLog", {"Update Travel Times ", starttime})  
   
   quit:   
   return(1)
   
  Return(1)
EndMacro

// Copy highway assignment results with loop number
Macro "Copy Hwy Outfile"(hwy_flow, loop)
    asgn_file_info = SplitPath(hwy_flow)
    asgn_file_path = asgn_file_info[1] + asgn_file_info[2] + asgn_file_info[3] +"_"+String(loop)+".csv" 
    hwy_am_toexp = OpenTable("hwy_am","FFB",{hwy_flow})
  ExportView(hwy_am_toexp+"|", "CSV", asgn_file_path,,{{"Header","TRUE"}})
    CloseView(hwy_am_toexp)
EndMacro


// Copy OD trip tables with loop number
Macro "Copy mat files"(inMatrix, loop)
    file_info = SplitPath(inMatrix)
    outMat = file_info[1] + file_info[2] + file_info[3] +"_"+String(loop)+".mtx" 
    CopyFile(inMatrix, outMat)
EndMacro


Macro "Compute Rmse"(hwy_flow)
  Shared Scen_Dir, loop_n, loop, run_type
  RMSE_summary = Scen_Dir+"\\outputs\\RMSE_Summary.txt"

  // Create summary output file with header(and a blank line)
  if (loop=1 | loop=null) then do
    fptr = OpenFile(RMSE_summary, "w")
    WriteLine(fptr, "====== Feedback Summary =======" )
    CloseFile(fptr)
  end 

  if loop > 1 then do
    asgn_file_info = SplitPath(hwy_flow)
    prev_asgn_file = asgn_file_info[1] + asgn_file_info[2] + asgn_file_info[3] +"_"+String(loop-1)+".csv" 
    curr_asgn_file = asgn_file_info[1] + asgn_file_info[2] + asgn_file_info[3] +"_"+String(loop)+".csv" 
    
    // Check on prev_asgn_file and if doesn't exist then get the next lowest loop 
    file_info = GetFileInfo(prev_asgn_file) 
    if file_info = Null then do
    	for f = 2 to loop-1 do
    	  prev_asgn_file = asgn_file_info[1] + asgn_file_info[2] + asgn_file_info[3] +"_"+String(loop-f)+".csv"  // checks in the reverse order
    	  file_info = GetFileInfo(prev_asgn_file) 
    	  if file_info != Null then goto foundPrevAsgn
    	end
    end

    foundPrevAsgn:
    
    oldfloM = OpenTable("oldfloM", "CSV", {prev_asgn_file}) 
    newfloM = OpenTable("newfloM", "CSV", {curr_asgn_file}) 
        
    vaboM = GetDataVector(oldfloM+"|", oldfloM+".AB_Time",)
    vbaoM = GetDataVector(oldfloM+"|", oldfloM+".BA_Time",)
    vabnM = GetDataVector(newfloM+"|", newfloM+".AB_Time",)
    vbanM = GetDataVector(newfloM+"|", newfloM+".BA_Time",)

    vd2M    = (vaboM-vabnM)*(vaboM-vabnM)
    sdif2M  = VectorStatistic(vd2M, "Sum", )
    LM      = VectorStatistic(vd2M, "Count", )
    rmseM   = Sqrt(sdif2M/(LM-1))
    avgobsM = VectorStatistic(vaboM, "Mean", )
    NORMSEM = 100*rmseM/avgobsM

    closeview(oldfloM)
    closeview(newfloM)

    fptr = OpenFile(RMSE_summary, "a+")
    WriteLine(fptr, "")
    WriteLine(fptr, "Period         : " + asgn_file_info[3])
    WriteLine(fptr, "Loop           : " + String(loop))
    WriteLine(fptr, "RMSE           : " + R2S(rmseM))    
    WriteLine(fptr, "Pct_RMSE       : " + R2S(NORMSEM)) 
    CloseFile(fptr)
  end
  Return(rmseM) 
EndMacro

Macro "Convergence"
    shared Scen_Dir, loop
    
    feedback_iteration=loop
    
    if feedback_iteration > 2 then do 
        
        periods = {"AM","MD","PM","OP"}
        classes = {"sov","hov"}
        
        RMSE_summary = Scen_Dir+"\\outputs\\Convergence_Summary.txt"

        fptr = OpenFile(RMSE_summary, "w")
        WriteLine(fptr, "====== Feedback Summary =======" )
        
        for feedback_iteration = 2 to 3 do        
            WriteLine(fptr, "")
            WriteLine(fptr, "-------- Iteration = " + String(feedback_iteration) + " --------")
            for class=1 to 2 do // sov and hov
                for p = 1 to periods.Length do
                    directory = Scen_Dir + "outputs\\Skims_iter" + string(feedback_iteration-1)
                    //directory = Scen_Dir + "outputs"
                    previous_skim_matrix = directory + "\\hwyskim_" + Lower(periods[p]) + "_" +classes[class] + "_" + i2s(feedback_iteration - 1) + ".mtx"
                    
                    directory = Scen_Dir + "outputs\\Skims_iter" + string(feedback_iteration)
                    //directory = Scen_Dir + "outputs"
                    current_skim_matrix = directory + "\\hwyskim_" + Lower(periods[p]) + "_" +classes[class] + "_"  + i2s(feedback_iteration) + ".mtx"
                    
                    m_prev_skim = OpenMatrix(previous_skim_matrix,)
                    m_curr_skim = OpenMatrix(current_skim_matrix,)
                    
                    matrix_prev_cores = GetMatrixCoreNames(m_prev_skim)
                    matrix_curr_cores = GetMatrixCoreNames(m_curr_skim)
                    
                    mc_prev_skim = CreateMatrixCurrency(m_prev_skim, matrix_prev_cores[1],,,)
                    mc_curr_skim = CreateMatrixCurrency(m_curr_skim, matrix_curr_cores[1],,,)
                    
                    rmse_array = MatrixRMSE(mc_prev_skim, mc_curr_skim)
                    rmse = rmse_array.RMSE
                    percent_rmse = rmse_array.RelRMSE

                    WriteLine(fptr, "")
                    WriteLine(fptr, "Period         : " + periods[p])
                    WriteLine(fptr, "Class         : " + classes[class])
                    WriteLine(fptr, "RMSE           : " + String(rmse))    
                    WriteLine(fptr, "Pct_RMSE       : " + String(percent_rmse)) 
                    
                    if percent_rmse < 0.1 then  converged = 1
                    else  converged = 0
                
                end
            end
            
        end // feedback
        
        CloseFile(fptr)
    
    end
    
    

EndMacro