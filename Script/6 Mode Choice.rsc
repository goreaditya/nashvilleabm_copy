//======================================================================================
//**************************************
//*      					Part 8  					   	        *
//*		               Transit Component - Mode Choice Model								 *
//**************************************

// Edited by: 
// nagendra.dhakar@rsginc.com
// Date: 06/25/2014 

// STEP 7: Execute mode choice model for the all purposes
Macro "ModeChoiceModel"(Args)
   
    shared Scen_Dir
     OutDir = Scen_Dir+"outputs\\"

    purposes = {"hbo","nhbw","nhbo"} 
    RunMacro("TCB Init")
    
    // Set environment variables for paths used in bat file
    {scen_drive, scen_dir,,} = SplitPath(Scen_Dir)
    SetEnvironmentVariable("Nashville_DRIVE", scen_drive)
    SetEnvironmentVariable("Nashville_DIR", scen_dir)
   
    for p = 1 to purposes.length do
       batfile = RunMacro("CreateBatch",purposes[p],1)
       // ok = RunMacro("TCB Run Command", 1, Upper(purposes[p]) + "Mode Choice", batfile)
       // if !ok then goto quit 
       // DeleteFile(batfile)
    end

    // Compute Mode choice in Parallel
    ok = RunMacro("Run in Parallel", {{Scen_Dir + "reference\\mchoice\\hbo.cmd"  , 1}})
    if !ok then goto quit
      
    ok = RunMacro("Run in Parallel", {{Scen_Dir + "reference\\mchoice\\nhbw.cmd" ,1},
                                      {Scen_Dir +"reference\\mchoice\\nhbo.cmd"  ,1}})   
    if !ok then goto quit
    /*
		// DeleteFile the temp PK and OP transit skims
		batch_ptr = OpenFile(OutDir + "deletefiles.bat", "w")
		WriteLine(batch_ptr, "REM temp transit skim files")
		WriteLine(batch_ptr, "del " + OutDir + "PK_*Skim.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "OP_*Skim.mtx")
		CloseFile(batch_ptr)
		RunProgram(OutDir + "deletefiles.bat", )		
   */
		
    Return(ok)
quit:
    SetEnvironmentVariable("Nashville_DRIVE", "")
    SetEnvironmentVariable("Nashville_DIR", "")
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
       WriteLine(batch, 'set JAVA_PATH="C:\\Program Files\\Java\\jdk1.7.0_79"')
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

