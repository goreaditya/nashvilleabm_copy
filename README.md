

Nashville ABM
==============
1. Get latest DaySim: 
    - Clone the DaySim github repository (https://github.com/RSGInc/DaySim) to your machine
    - Open DaySim.sln solution with Microsoft Visual Studio Express 2015 or later (C# 6+)
    - Build + Rebuild Solution outputs DaySim_dist\DaySim.exe
    - Copy all files in "DaySim_dist" to "2010\DaySim"
    
2. Update all paths in 2040model.lst and model directory in nashville4.bin to replicate your setup.

3. Update R path in daysim_summaries.cmd (./DaySimSummaries/daysim_summaries.cmd)

    "C:\Program Files\R\R-3.2.2\bin\x64\R.exe" CMD BATCH --no-save main.R log.txt

4. Unzip the following file to two locations:

  node_node_distances.zip 

  to:
  
  ParcelInputs\BufferTool\2010\node_node_distances.dat

  2010\DaySim\node_node_distances.dat

5. Requires Git Large File Storage (LFS)
