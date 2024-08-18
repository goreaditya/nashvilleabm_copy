The below are instructions to perform external trip matrix adjustment based on adjustment factors from historical traffic counts

TRUCK
1. use "calculations\SUTruckAdjFactor_Calculation_v1.xlsx" and "calculations\MUTruckAdjFactor_Calculation_v1.xlsx" to calculate row and col adjustment factors by external stations
	-Calculate projected counts based on historical traffic count and perform optimizatioin in the spreadsheets to calculate optimized factors
2. use those factors to update "inputs\SU_Adj_Factor.bin" and "inputs\MU_Adj_Factor.bin". Note that only external stations (>=2930) will have the updated factors (rowsum and colsum). other zones will always be set to 1.
3. run "scripts\ExtMatrixAdjustment_FutureYear_Truck.rsc" to generate scaled trip tables. 
	- Note make sure Macro "Settings" reflects your setup. 
	- Presently, the script assumes that input tables (ext matrices and adj factors) are under "inputs" in the scenario folder.  Scaled trips will be output in the "inputs" folder itself.

AUTO
1. Use "calculations\AutoAdjFactor_Calculation_v1.xlsx" to calculate row and col adjustment factors by external stations
	-Calculate projected counts based on historical traffic count and perform optimizatioin in the spreadsheets to calculate optimized factors
2. use those factors to update "inputs\AUTO_Adj_Factor.bin"
3. run "scripts\ExtMatrixAdjustment_FutureYear_Auto.rsc" to generate scaled trip tables. 
	- Note make sure Macro "Settings" reflects your setup. 
	- Presently, the script assumes that input tables (ext matrices and adj factors) are under "inputs" in the scenario folder.  Scaled trips will be output in the "inputs" folder itself.
