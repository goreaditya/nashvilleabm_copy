
 // Post Process Transit Skim Matrices for Mode Choice Model & Compress Skims
 Macro "ProcessTransitSkimsforMC"(Args)
 	RunMacro("HwycadLog", {"Process transit skims", null})
    shared scen_data_dir  
    
    //  Define Parameters                                          
    OutDir                = scen_data_dir + "outputs\\"                          // path of the output folder 
    Periods               = {"AM","MD","PM","OP"}                                // Periods defined in the transit model
    PeriodsHwy            = {"AM","MD"}                                          // Highway Time of Day Periods used in Transit
    Modes                 = {"Local","Brt", "ExpBus", "UrbRail", "ComRail"}      // List of transit modes
    AccessModes           = {"Walk","Drive"}                                     // List of access modes for building paths
    DeleteTempOutputFiles = Args.[DeleteTempOutputFiles]     
    IDTable               = Args.[IDTable] 
    TerminalTimeMtx       = OutDir + "terminal_time.mtx"
    
    RunMacro("TCB Init")

    // Close any opened views - need to find a way to close the rts file, for now comment this out and do this manually
    //vws = GetViewNames()
    //for i = 1 to vws.length do CloseView(vws[i]) end

    // open ID Table view   
    IDTable_vw = OpenTable("equivalancy", "FFB", {IDTable}) 

    // STEP 1: Change the row and column IDs for terminal time matrix
    inmat  = TerminalTimeMtx
    outmat = OutDir +"terminal_time2.mtx"
    new_mat = CopyFile(inmat,outmat)

    // STEP 2: Change the row and column IDs for Highway Skims
    classes = {"sov","hov"}
    for class = 1 to classes.length do
        for iper=1 to PeriodsHwy.length do
           inmat  = OutDir + "hwyskim_" + PeriodsHwy[iper] +"_" +classes[class]  + ".mtx"
           outmat = OutDir + "hwyskim_" + PeriodsHwy[iper] +"_" +classes[class]  + "2.mtx"
           new_mat = CopyFile(inmat,outmat)
        end
    end    

    // STEP 3: Change the row and column IDs for Transit Skims
    for iper=1 to Periods.length do
	    for iacc=1 to AccessModes.Length do
			for imode=1 to Modes.Length do
				inmat  = OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + ".mtx"
				outmat = OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx"
				new_mat = CopyFile(inmat,outmat)
			end   // transit 
		end    // access  
    end    // period 

   // Close view 
   CloseView(IDTable_vw) 
   
  // STEP 4: Set Null values to Zero, Also Zero-Out skim tables based on path hierarchy
  for iper=1 to Periods.length do
	  for iacc=1 to AccessModes.Length do
      for imode=1 to Modes.Length do
		            
		            timevar = "TransitTime"+Periods[iper]+"_"
                m = OpenMatrix(OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx", )
                
                mc1 = CreateMatrixCurrency(m, "Generalized Cost", , , )
                mc2 = CreateMatrixCurrency(m, "Fare", , , )
                mc3 = CreateMatrixCurrency(m, "In-Vehicle Time", , , )
                mc4 = CreateMatrixCurrency(m, "Initial Wait Time", , , )
                mc5 = CreateMatrixCurrency(m, "Transfer Wait Time", , , )
                mc6 = CreateMatrixCurrency(m, "Transfer Penalty Time", , , )
                mc7 = CreateMatrixCurrency(m, "Transfer Walk Time", , , )
                mc8 = CreateMatrixCurrency(m, "Access Walk Time", , , )
                mc9 = CreateMatrixCurrency(m, "Egress Walk Time", , , )
                mc10 = CreateMatrixCurrency(m, "Access Drive Time", , , )
                mc11 = CreateMatrixCurrency(m, "Dwelling Time", , , )
                mc12 = CreateMatrixCurrency(m, "Number of Transfers", , , )
                mc13 = CreateMatrixCurrency(m, "In-Vehicle Distance", , , )
                mc14 = CreateMatrixCurrency(m, "Access Drive Distance", , , )
                mc15 = CreateMatrixCurrency(m, timevar + " (New Local Bus)", , , )
                mc16 = CreateMatrixCurrency(m, timevar + " (Project Local Bus)", , , )
                mc17 = CreateMatrixCurrency(m, timevar + " (Express Bus)", , , )
                mc18 = CreateMatrixCurrency(m, timevar + " (Commuter Bus)", , , )
                mc19 = CreateMatrixCurrency(m, timevar + " (Existing BRT)", , , )
                mc20 = CreateMatrixCurrency(m, timevar + " (New BRT)", , , )
                mc21 = CreateMatrixCurrency(m, timevar + " (Urban Rail)", , , )
                mc22 = CreateMatrixCurrency(m, timevar + " (Commuter Rail)", , , )
                mc23 = CreateMatrixCurrency(m, timevar + " (New FG)", , , )
                mc24 = CreateMatrixCurrency(m, timevar + " (Project FG)", , , )
				mc25 = CreateMatrixCurrency(m, timevar + " (Commuter Rail Shuttles)", , , )
                
                mc1 := Nz(mc1)
                mc2 := Nz(mc2)
                mc3 := Nz(mc3)
                mc4 := Nz(mc4)
                mc5 := Nz(mc5)
                mc6 := Nz(mc6)
                mc7 := Nz(mc7)
                mc8 := Nz(mc8)
                mc9 := Nz(mc9)
                mc10 := Nz(mc10)
                mc11 := Nz(mc11)
                mc12 := Nz(mc12)
                mc13 := Nz(mc13)
                mc14 := Nz(mc14)
                mc15 := Nz(mc15)
                mc16 := Nz(mc16)
                mc17 := Nz(mc17)
                mc18 := Nz(mc18)
                mc19 := Nz(mc19)
                mc20 := Nz(mc20)
                mc21 := Nz(mc21)
                mc22 := Nz(mc22)
                mc23 := Nz(mc23)
                mc24 := Nz(mc24)
				        mc25 := Nz(mc25)

                if (Modes[imode]="Local") then do
                   FillMatrix(mc2, null, null, {"Multiply", 100}, )
                end

/*                new_mat = CombineMatrices({mc1, mc2, mc3, mc4, mc5, mc6, mc7, mc8, mc9, mc10, mc11, mc12, mc13,
                                           mc14, mc15, mc16, mc17, mc18, mc19, mc20, mc21, mc22, mc23, mc24},
                                           {{"File Name", OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx"},
                                            {"Label", "New Matrix"},{"Operation", "Union"},{"Compression", 1},
                                            {"Missing is zero", "Yes"}})
 */

                if (Modes[imode]="Brt") then do
                  mc1 := if ((mc19 + mc20) <= 0) then 0 else mc1
                  mc2 := if ((mc19 + mc20) <= 0) then 0 else mc2
                  mc3 := if ((mc19 + mc20) <= 0) then 0 else mc3
                  mc4 := if ((mc19 + mc20) <= 0) then 0 else mc4
                  mc5 := if ((mc19 + mc20) <= 0) then 0 else mc5
                  mc6 := if ((mc19 + mc20) <= 0) then 0 else mc6
                  mc7 := if ((mc19 + mc20) <= 0) then 0 else mc7
                  mc8 := if ((mc19 + mc20) <= 0) then 0 else mc8
                  mc9 := if ((mc19 + mc20) <= 0) then 0 else mc9
                  mc10 := if ((mc19 + mc20) <= 0) then 0 else mc10
                  mc11 := if ((mc19 + mc20) <= 0) then 0 else mc11
                  mc12 := if ((mc19 + mc20) <= 0) then 0 else mc12
                  mc13 := if ((mc19 + mc20) <= 0) then 0 else mc13
                  mc14 := if ((mc19 + mc20) <= 0) then 0 else mc14
                  mc15 := if ((mc19 + mc20) <= 0) then 0 else mc15
                  mc16 := if ((mc19 + mc20) <= 0) then 0 else mc16
                  mc17 := if ((mc19 + mc20) <= 0) then 0 else (mc17 + mc18)   // for DaySim - as only express bus ivt is provided in the roster, therefore, this core should also include commuter bus.
                  mc18 := if ((mc19 + mc20) <= 0) then 0 else mc18
                  mc19 := if ((mc19 + mc20) <= 0) then 0 else mc19
                  mc20 := if ((mc19 + mc20) <= 0) then 0 else mc20
                  mc21 := if ((mc19 + mc20) <= 0) then 0 else mc21
                  mc22 := if ((mc19 + mc20) <= 0) then 0 else (mc22 + mc25)    // for DaySim - as only commuter rail ivt is provided in the roster, therefore, this core should also include commuter rail shuttle.
                  mc23 := if ((mc19 + mc20) <= 0) then 0 else mc23
                  mc24 := if ((mc19 + mc20) <= 0) then 0 else mc24
				          mc25 := if ((mc19 + mc20) <= 0) then 0 else mc25
                
                  FillMatrix(mc2, null, null, {"Multiply", 100}, )
/*                new_mat = CombineMatrices({mc1, mc2, mc3, mc4, mc5, mc6, mc7, mc8, mc9, mc10, mc11, mc12, mc13,
                                           mc14, mc15, mc16, mc17, mc18, mc19, mc20, mc21, mc22, mc23, mc24},
                                           {{"File Name", OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx"},
                                            {"Label", "New Matrix"},{"Operation", "Union"},{"Compression", 1},
                                            {"Missing is zero", "Yes"}})
  */              end

                if (Modes[imode]="ExpBus") then
                do
                  mc1 := if ((mc17 + mc18) <= 0) then 0 else mc1
                  mc2 := if ((mc17 + mc18) <= 0) then 0 else mc2
                  mc3 := if ((mc17 + mc18) <= 0) then 0 else mc3
                  mc4 := if ((mc17 + mc18) <= 0) then 0 else mc4
                  mc5 := if ((mc17 + mc18) <= 0) then 0 else mc5
                  mc6 := if ((mc17 + mc18) <= 0) then 0 else mc6
                  mc7 := if ((mc17 + mc18) <= 0) then 0 else mc7
                  mc8 := if ((mc17 + mc18) <= 0) then 0 else mc8
                  mc9 := if ((mc17 + mc18) <= 0) then 0 else mc9
                  mc10 := if ((mc17 + mc18) <= 0) then 0 else mc10
                  mc11 := if ((mc17 + mc18) <= 0) then 0 else mc11
                  mc12 := if ((mc17 + mc18) <= 0) then 0 else mc12
                  mc13 := if ((mc17 + mc18) <= 0) then 0 else mc13
                  mc14 := if ((mc17 + mc18) <= 0) then 0 else mc14
                  mc15 := if ((mc17 + mc18) <= 0) then 0 else mc15
                  mc16 := if ((mc17 + mc18) <= 0) then 0 else mc16
                  mc17 := if ((mc17 + mc18) <= 0) then 0 else (mc17 + mc18)
                  mc18 := if ((mc17 + mc18) <= 0) then 0 else mc18
                  mc19 := if ((mc17 + mc18) <= 0) then 0 else mc19
                  mc20 := if ((mc17 + mc18) <= 0) then 0 else mc20
                  mc21 := if ((mc17 + mc18) <= 0) then 0 else mc21
                  mc22 := if ((mc17 + mc18) <= 0) then 0 else (mc22 + mc25)
                  mc23 := if ((mc17 + mc18) <= 0) then 0 else mc23
                  mc24 := if ((mc17 + mc18) <= 0) then 0 else mc24
				          mc25 := if ((mc17 + mc18) <= 0) then 0 else mc25
                
                FillMatrix(mc2, null, null, {"Multiply", 100}, )
/*                new_mat = CombineMatrices({mc1, mc2, mc3, mc4, mc5, mc6, mc7, mc8, mc9, mc10, mc11, mc12, mc13,
                                           mc14, mc15, mc16, mc17, mc18, mc19, mc20, mc21, mc22, mc23, mc24},
                                           {{"File Name", OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx"},
                                            {"Label", "New Matrix"},{"Operation", "Union"},{"Compression", 1},
                                            {"Missing is zero", "Yes"}})
 */               end

                if (Modes[imode]="UrbRail") then do
                  mc1 := if (mc21 <= 0) then 0 else mc1
                  mc2 := if (mc21 <= 0) then 0 else mc2
                  mc3 := if (mc21 <= 0) then 0 else mc3
                  mc4 := if (mc21 <= 0) then 0 else mc4
                  mc5 := if (mc21 <= 0) then 0 else mc5
                  mc6 := if (mc21 <= 0) then 0 else mc6
                  mc7 := if (mc21 <= 0) then 0 else mc7
                  mc8 := if (mc21 <= 0) then 0 else mc8
                  mc9 := if (mc21 <= 0) then 0 else mc9
                  mc10 := if (mc21 <= 0) then 0 else mc10
                  mc11 := if (mc21 <= 0) then 0 else mc11
                  mc12 := if (mc21 <= 0) then 0 else mc12
                  mc13 := if (mc21 <= 0) then 0 else mc13
                  mc14 := if (mc21 <= 0) then 0 else mc14
                  mc15 := if (mc21 <= 0) then 0 else mc15
                  mc16 := if (mc21 <= 0) then 0 else mc16
                  mc17 := if (mc21 <= 0) then 0 else (mc17 + mc18)
                  mc18 := if (mc21 <= 0) then 0 else mc18
                  mc19 := if (mc21 <= 0) then 0 else mc19
                  mc20 := if (mc21 <= 0) then 0 else mc20
                  mc21 := if (mc21 <= 0) then 0 else mc21
                  mc22 := if (mc21 <= 0) then 0 else (mc22 + mc25)
                  mc23 := if (mc21 <= 0) then 0 else mc23
                  mc24 := if (mc21 <= 0) then 0 else mc24
				          mc25 := if (mc21 <= 0) then 0 else mc25
               
                FillMatrix(mc2, null, null, {"Multiply", 100}, )
/*                new_mat = CombineMatrices({mc1, mc2, mc3, mc4, mc5, mc6, mc7, mc8, mc9, mc10, mc11, mc12, mc13,
                                           mc14, mc15, mc16, mc17, mc18, mc19, mc20, mc21, mc22, mc23, mc24},
                                           {{"File Name", OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx"},
                                            {"Label", "New Matrix"},{"Operation", "Union"},{"Compression", 1},
                                            {"Missing is zero", "Yes"}})
*/              end

                if (Modes[imode]="ComRail") then do
                  mc1 := if ((mc22 + mc25) <= 0) then 0 else mc1
                  mc2 := if ((mc22 + mc25) <= 0) then 0 else mc2
                  mc3 := if ((mc22 + mc25) <= 0) then 0 else mc3
                  mc4 := if ((mc22 + mc25) <= 0) then 0 else mc4
                  mc5 := if ((mc22 + mc25) <= 0) then 0 else mc5
                  mc6 := if ((mc22 + mc25) <= 0) then 0 else mc6
                  mc7 := if ((mc22 + mc25) <= 0) then 0 else mc7
                  mc8 := if ((mc22 + mc25) <= 0) then 0 else mc8
                  mc9 := if ((mc22 + mc25) <= 0) then 0 else mc9
                  mc10 := if ((mc22 + mc25) <= 0) then 0 else mc10
                  mc11 := if ((mc22 + mc25) <= 0) then 0 else mc11
                  mc12 := if ((mc22 + mc25) <= 0) then 0 else mc12
                  mc13 := if ((mc22 + mc25) <= 0) then 0 else mc13
                  mc14 := if ((mc22 + mc25) <= 0) then 0 else mc14
                  mc15 := if ((mc22 + mc25) <= 0) then 0 else mc15
                  mc16 := if ((mc22 + mc25) <= 0) then 0 else mc16
                  mc17 := if ((mc22 + mc25) <= 0) then 0 else (mc17 + mc18)
                  mc18 := if ((mc22 + mc25) <= 0) then 0 else mc18
                  mc19 := if ((mc22 + mc25) <= 0) then 0 else mc19
                  mc20 := if ((mc22 + mc25) <= 0) then 0 else mc20
                  mc21 := if ((mc22 + mc25) <= 0) then 0 else mc21
                  mc22 := if ((mc22 + mc25) <= 0) then 0 else (mc22 + mc25)
                  mc23 := if ((mc22 + mc25) <= 0) then 0 else mc23
                  mc24 := if ((mc22 + mc25) <= 0) then 0 else mc24
				          mc25 := if ((mc22 + mc25) <= 0) then 0 else mc25
                
                   FillMatrix(mc2, null, null, {"Multiply", 100}, )
/*                new_mat = CombineMatrices({mc1, mc2, mc3, mc4, mc5, mc6, mc7, mc8, mc9, mc10, mc11, mc12, mc13,
                                           mc14, mc15, mc16, mc17, mc18, mc19, mc20, mc21, mc22, mc23, mc24},
                                           {{"File Name", OutDir + Periods[iper] + "_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx"},
                                            {"Label", "New Matrix"},{"Operation", "Union"},{"Compression", 1},
                                            {"Missing is zero", "Yes"}})
*/             end


	      end
	   end
  end

  // For Airport Model - copy AM as PK - temp solution while going from two time periods to four time periods - nagendra.dhakar@rsginc.com				
	for iacc=1 to AccessModes.Length do
		for imode=1 to Modes.Length do
				
				inmat  = OutDir + "AM_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx"
				outmat = OutDir + "PK_" + AccessModes[iacc] + Modes[imode] + "Skim.mtx"
				new_mat = CopyFile(inmat,outmat)
				
		 end   // transit 
	end    // access  

	if (DeleteTempOutputFiles = 1) then do
		batch_ptr = OpenFile(OutDir + "deletefiles.bat", "w")
		WriteLine(batch_ptr, "REM temp transit skim files")
		WriteLine(batch_ptr, "del " + OutDir + "??_WalkLocal.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "??_WalkBrt.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "??_WalkExpBus.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "??_WalkUrbRail.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "??_WalkComRail.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "??_DriveLocal.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "??_DriveBrt.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "??_DriveExpBus.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "??_DriveUrbRail.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "??_DriveComRail.mtx")
		WriteLine(batch_ptr, "REM temp files from path building")
		WriteLine(batch_ptr, "del " + OutDir + "*.tps")
		WriteLine(batch_ptr, "del " + OutDir + "*_pnr_time.mtx")
		WriteLine(batch_ptr, "del " + OutDir + "*_pnr_node.mtx")
		WriteLine(batch_ptr, "REM temp files from mode choice post processing")
		WriteLine(batch_ptr, "del " + OutDir + "???Temp.mtx")
		WriteLine(batch_ptr, "REM temp files from the preliminary transit assignment for calculating the travel times")
		WriteLine(batch_ptr, "del " + OutDir + "*PreloadFlow.bin")
		WriteLine(batch_ptr, "del " + OutDir + "*PreloadFlow.dcb")
		WriteLine(batch_ptr, "del " + OutDir + "*PreloadWalkFlow.bin")
		WriteLine(batch_ptr, "del " + OutDir + "*PreloadWalkFlow.dcb")
		CloseFile(batch_ptr)
		RunProgram(OutDir + "deletefiles.bat", )
    end
  Return(1)
quit:
  Return(ret_value)
EndMacro
