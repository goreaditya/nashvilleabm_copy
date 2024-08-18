REM %~dp0 is the script directory which we pass as starting point of search for DaySim config files
python %~dp0\..\DaySim\DaySim.Tests\DaySim.Tests.external\compare_output_directories\regress_subfolders.py --regional_data_directory %~dp0
