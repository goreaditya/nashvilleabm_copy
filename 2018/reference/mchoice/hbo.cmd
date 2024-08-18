%Nashville_DRIVE%
cd "%Nashville_DIR%"

set OLDPATH=%PATH%
set OLDJAVAPATH=%JAVA_PATH%
set JAVA_PATH="C:\Program Files\Java\jdk1.7.0_79"
set TRANSCAD_LIB=C:\Program Files\TransCAD 8.0
set PATH=C:\Program Files\TransCAD 8.0\;C:\Program Files\TransCAD 8.0\GISDK\Matrices\;%JAVA_PATH%\bin;%OLDPATH%
set CLASSPATH=%Nashville_DIR%\reference\mchoice;%Nashville_DIR%\reference\mchoice\nashvilleMC.jar;%TRANSCAD_LIB%\GISDK\Matrices\TranscadMatrix.jar

java -Xms2000m -Xmx2000m -Dlog4j.configuration=info_log4j.xml com.pb.nashville.modeChoice.ModeChoiceApplication reference\mchoice\hbo.properties 1 HBO
 
if not exist "outputs\logsum_hbo.mtx"  exit 1
exit 0

set JAVA_PATH=%OLDJAVAPATH%
set PATH=%OLDPATH%
set CLASSPATH=%OLDCLASSPATH%
