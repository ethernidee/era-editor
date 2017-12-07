@echo off
:start
cls
set h3dir=D:\Heroes 3
copy /Y EraMap.dll "%h3dir%\eramap.dll"
copy /Y EraMap.map "%h3dir%\EraMap.map"
php "%h3dir%\Tools\ExeMapCompiler\compile.phc" "eramap.map" "./DebugMaps"
echo.
echo.
echo %date% %time%
echo.
pause
goto start