@echo off
cls
echo Version (X.X.X.X [Text]):
set /P v=
verpatch eramap.dll "%v%" /va