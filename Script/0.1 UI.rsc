
Macro "Model"
 RunDbox("MMC Model")
endMacro

macro "MMC Model Version"
    model_version = 2009080609
    required_tc_build = 6010
    required_tc_version = 6.0
    return({model_version, required_tc_build, required_tc_version})
endmacro

dbox "MMC Model"
    right, center toolbox nokeyboard
    title: "Nashville Area MPO 2040 LRTP Model"

/*
    init do
       shared  project_dbox, ui_file, ScenArr, ScenSel, prj_dry_run, scen_dir,  feedback_iteration
		feedback_iteration=1
       ui_file = GetInterface()
       model_title = "MMC Model"
       {drive, dir,,} = SplitPath(ui_file)
       bmp_path = drive + dir + "bmp\\"
       script_path= drive + dir + "\\"

       Model_Info = RunMacro("TCP Read Model Table", model_title)

        
       if Model_Info = null then return()
       RunMacro("update all")

       project_dbox = 1
       single_stage = 1
      enditem

    update do
        if project_dbox = -99 then
            runmacro("closing")
        else
            runmacro("update dbox")
      enditem
*/

    // Initialize DBOX
    init do
       shared  project_dbox, ui_file, ScenArr, ScenSel, Scen_Dir, 
       StepFlagVec, loop_n, loop, run_type, feedbackConverge 

       ui_file = GetInterface()
       model_title = "MMC Model"
       {drive, dir,,} = SplitPath(ui_file)
       bmp_path = drive + dir + "bmp\\"
       script_path= drive + dir + "\\"

       {ModelInfo, StageInfo, MacroInfo,} = RunMacro("TCP Load Model", model_title)

       {model_table,,,model_version,} = ModelInfo
       {StepMacro, StepTitle, StepFlag, StepAcce} = MacroInfo
       StageName = StageInfo[1]
       stages = StageName.length

       if !RunMacro("TCP Update Project Dbox", model_title, stages, &ScenNames) then return()
       if !RunMacro("TCP Convert Step Flags", StepFlag, StageName, &StepFlagVec) then return()
       RunMacro("feedback init")
       
       single_stage = 0            // 0 = False, 1 = True
       run_type = 1                // 1 = Single Stage, 2 = Current Loop, 3 = All Loops
       project_dbox = 1            
       feedbackConverge = 0.001    // Feedback Loop Convergence (to use in All Loops)
    enditem
    
    // Update DBOX
    update do
       if project_dbox = -99 then
          RunMacro("closing")
       else do
          // RunMacro("update dbox")
          if !RunMacro("TCP Update Project Dbox", model_title, stages, &ScenNames) then return()
          if cur_loop <= loop_n then StepFlag = StepFlagVec[cur_loop] else StepFlag = StepFlagVec[all_loops]
       end
    enditem
    close do RunMacro("closing") enditem

    // Define GUI
    button  0,0
    icons: "bmp\\2040.bmp"

    frame 0.5, 6, 39.0, 5 prompt: "Scenarios"
    scroll list 1.5, 7.0, 37.0, 3.5 multiple list: ScenNames variable: ScenSel do
       RunMacro("TCP Update Scenarios", model_title, stages, model_table)
    enditem
       
    // Run and Feedback Loop Settings
    radio list  0.5,11.5, 39, 6 prompt: "Run" variable: run_type
    radio button 2, 12.5 prompt: "Stage"      help: "Check to run one stage"
    radio button 14, Same prompt: "Loop"      help: "Check to run one loop"
    radio button 25, Same prompt: "All Loops" help: "Check to run all loops"
      
    popdown menu 28, 15.5, 7, 10 prompt: "Max. Feedback Loops"  list: MFB_List  variable: loop_n do
      RunMacro("update feedback")
    enditem     
    popdown menu 28, 14, 7, 10 prompt: "Start Feedback Loop"  list: FB_List  variable: cur_loop do
       if cur_loop <= loop_n then StepFlag = StepFlagVec[cur_loop] else StepFlag = StepFlagVec[all_loops]
    enditem    
 
    	
    button   2.0, 18, 18, 1.5 prompt: "Model Table"
      help: "Click to change model table", "Current Model Table: " + model_table do
      Model_Info = RunMacro("TCP Choose Model Table", model_title, model_table)
      // RunMacro("update all")
    enditem
    button  after, same, 18, 1.5 prompt: "Setup"
      help: "Click to modify current scenario" do
      RunDbox("TCP Scenario Manager", model_title, model_table)
    enditem
/*
    button   2.0, 20, 37, 1.6 prompt: "Parameters"
      help: "Click to change model table", "Current Model Table: " + model_table do
      Model_Info = RunMacro("TCP Choose Model Table", model_title, model_table)
      // RunMacro("update all")
    enditem
*/
    button "MMC_A1" 1, 22 icons: "bmp\\plansetup.bmp" do cur_stage = 1  Runmacro("set steps") enditem
    button "MMC_B1" after, same, 19.0, 1.6 disabled prompt:StageName[1]  do cur_stage = 1  Runmacro("run stages") enditem
    button "MMC_C1" after, same icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 1) enditem

    button "MMC_A2" 1, 24 icons: "bmp\\plantripgen.bmp" do cur_stage = 2  Runmacro("set steps") enditem
    button "MMC_B2" after, same, 19.0, 1.6 disabled prompt:StageName[2]  do cur_stage = 2  Runmacro("run stages") enditem
    button "MMC_C2" after, same icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 2) enditem

    button "MMC_A3" 1, 26 icons: "bmp\\planskim.bmp" do cur_stage = 3  Runmacro("set steps") enditem
    button "MMC_B3" after, same, 19.0, 1.6 disabled prompt:StageName[3]  do cur_stage = 3  Runmacro("run stages") enditem
    button "MMC_C3" after, same icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 3) enditem

    button "MMC_A4" 1, 28 icons: "bmp\\truck.bmp" do cur_stage = 4  Runmacro("set steps") enditem
    button "MMC_B4" after, same, 19.0, 1.6 disabled prompt:StageName[4]  do cur_stage = 4  Runmacro("run stages") enditem
    button "MMC_C4" after, same icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 4) enditem

    button "MMC_A5" 1, 30 icons: "bmp\\plantripdist.bmp" do cur_stage = 5  Runmacro("set steps") enditem
    button "MMC_B5" after, same, 19.0, 1.6 disabled prompt:StageName[5]  do cur_stage = 5  Runmacro("run stages") enditem
    button "MMC_C5" after, same icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 5) enditem

    button "MMC_A6" 1, 32 icons: "bmp\\planmodesplit.bmp" do cur_stage = 6  Runmacro("set steps") enditem
    button "MMC_B6" after, same, 19.0, 1.6 disabled prompt:StageName[6]  do cur_stage = 6  Runmacro("run stages") enditem
    button "MMC_C6" after, same icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 6) enditem
    
    button "MMC_A8" 1, 34 icons: "bmp\\daysim.bmp" do cur_stage = 7  Runmacro("set steps") enditem
    button "MMC_B8" after, same, 19.0, 1.6 disabled prompt:StageName[7]  do cur_stage = 7  Runmacro("run stages") enditem
    button "MMC_C8" after, same icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 7) enditem
    
    button "MMC_A7" 1, 36 icons: "bmp\\planassign.bmp" do cur_stage = 8  Runmacro("set steps") enditem
    button "MMC_B7" after, same, 19.0, 1.6 disabled prompt:StageName[8]  do cur_stage = 8  Runmacro("run stages") enditem
    button "MMC_C7" after, same icons: "bmp\\ViewButton.bmp", "bmp\\ViewButton.bmp", "bmp\\ViewButton2.bmp" do RunMacro("TCP Model Show", ScenArr, 8) enditem
   

    button     1,  after, 36, 1.6  prompt: "Utilities" do RunDbox("MMC Utilities") enditem
    button  same, after, 36, 1.6  prompt: "Quit"      do Runmacro("closing") enditem

    text  25, after variable: "v " + i2s(model_version)

    Macro "set steps" do
      SetAlternateInterface()
      RunDbox("TCP Set Step Flags", StepTitle[cur_stage], &StepFlag[cur_stage], StepAcce[cur_stage])
    enditem

    Macro "run stages" do
      // Check scenario info array and get scenario directory
      RunMacro("TCP Check Model Table Value Changes", model_title, model_table, ScenArr, ScenSel)
      Scen_Dir=ScenArr[ScenSel[1]][3]
      RunMacro("HwycadLog", {" ******************* STARTED Nashville ABM 2019 - Version 19.1.0 ******************* ", null})
      // Check if to run single stage or not       
      if run_type = 1 then single_stage = 1 else single_stage = 0
      if RunMacro("TCP Check Stage Files", cur_stage, single_stage, StepFlag, ScenArr, ScenSel) then
         RunMacro("TCP Run Scen Stages", cur_stage, cur_loop, run_type, StepMacro, &StepFlag, ScenArr, ScenSel,)
	  RunMacro("HwycadLog", {" ******************* FINISHED Nashville ABM 2019 - Version 19.1.0 ******************* ", null})
   enditem

/*      
    Macro "update all" do
     if Model_Info <> null then do
       {model_table, model_version, StepMacro, StepTitle, StepFlag, StepAcce, StageName} = Model_Info
       if !RunMacro("TCP Update Project Dbox", model_title, stages, &ScenNames) then RunMacro("closing")
     end
    enditem
*/
    Macro "feedback init" do
      all_loops = StepFlagVec.length     // max. # of feedback loops
      loop_n = all_loops-1               // max. # of loops that can be chosen, excluding final-steps loop
      Dim MFB_List[loop_n]
      for i = 1 to loop_n do MFB_List[i] = i end
      RunMacro("update feedback")
    enditem

    Macro "update feedback" do
      FB_List = Subarray(MFB_List, 1, loop_n)+ {"Final"} 
      cur_loop = 1
      StepFlag = StepFlagVec[cur_loop]
    enditem

    Macro "closing" do
       if RunMacro("TCP Close Model Dbox") = 1 then return()
    enditem
    
endDbox

dbox "MMC Utilities" (ScenSel, ScenArr)
    title: "Utilities "
    
    init do
        RunMacro("TCB Init")
        //ArgArr = ScenArr[ ScenSel[1] ][5]
        //Args = RunMacro("TCP Convert to Argument Options", ArgArr)
	endItem

	Frame 1,1,40,10 Prompt:"Interface Tools: "
		Button "Remove Progress Bar" 3.5,2.5, 35, 2 do
		    on error goto quit
		    on notfound goto quit
		    while (true) do DestroyProgressBar() end
		    quit:
		    return()
		endItem
		text "" same, after, 1, .3 
		Button "Close All Files" same,after, 35, 2 do
			runmacro("G30 File Close All")
		endItem
		
		Button "Rename Logsum Matrices" same,after, 35, 2 do
		RunMacro("rename")
		endItem
		text "" same, after, 1, .3 
	
	Frame 1,12,40,10 Prompt:"Model Calibration: "
		Button "Model performace" 3.5,13.5, 35, 2 Disabled do
		RunMacro("Performance")
		endItem
		
		text "" same, after, 1, .3 
		Button "Trip Length Distribution" same,after, 35, 2 Disabled do
		RunMacro("disc")
		endItem
		
		text "" same, after, 1, .3 
			Button "Air Quality Analysis Output" same,after, 35, 2 Disabled do
			RunMacro("TravelSpeed")
			endItem

    Button "Done"  13, 24, 15,1.5 cancel do Return() endItem
    text " " same, after 
endDbox