@echo off
setlocal enabledelayedexpansion
REM E:\Projects\Clients\NashvilleMPO\ModelUpdate2023\GitHub\nashvillePopSim\Setup\software\Anaconda2\envs\py3env\python.exe auto_validation.py E:\Projects\Clients\NashvilleMPO\ModelUpdate2023\Model\Development\nashabm_TCAD9_transit 2018

REM Get the directory of the batch file
set current_dir=%~dp0
echo current dir is %current_dir%

REM Remove the trailing backslash if present
if "%current_dir:~-1%"=="\" set current_dir=%current_dir:~0,-1%

REM Go up four directories
for /l %%i in (1,1,4) do (
    set current_dir=!current_dir!\..
)

REM Resolve the full path
for %%i in ("!current_dir!") do set parent_dir=%%~fi

REM Define the final path
set final_path=%parent_dir%

REM Display the final path for debugging purposes
echo Final path: %final_path%

REM Check if the directory exists
if not exist "%final_path%" (
    echo The path %final_path% does not exist.
    exit /b 1
)

REM Call the Python script with the dynamically set path and redirect error messages
E:\Projects\Clients\NashvilleMPO\ModelUpdate2023\GitHub\nashvillePopSim\Setup\software\Anaconda2\envs\py3env\python.exe auto_validation.py %final_path% 2018 2> error_log.txt

REM Check for errors
if %errorlevel% neq 0 (
    echo An error occurred. See error_log.txt for details.
    pause
) else (
    echo Script executed successfully.
)

endlocal

