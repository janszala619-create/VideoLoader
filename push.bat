@echo off
REM ============================================================
REM  VideoLoader - Aenderungen zu GitHub hochladen (Push)
REM  Einfach diese Datei doppelklicken.
REM ============================================================
cd /d "%~dp0"

echo.
echo === VideoLoader: Hochladen zu GitHub ===
echo.

REM Aktuellen Branch anzeigen
for /f "delims=" %%b in ('git branch --show-current') do set BRANCH=%%b
echo Aktueller Branch: %BRANCH%
echo.

REM Alle Aenderungen vormerken
git add -A

REM Pruefen, ob es ueberhaupt etwas zu commiten gibt
git diff --cached --quiet
if %errorlevel%==0 (
    echo Keine neuen Aenderungen zum Hochladen.
    echo Versuche trotzdem, ausstehende Commits zu pushen...
    echo.
    goto push
)

REM Commit-Nachricht abfragen (Enter = Standardtext mit Datum/Uhrzeit)
set "MSG="
set /p MSG="Kurze Beschreibung der Aenderung (Enter = automatisch): "
if "%MSG%"=="" set "MSG=Update %DATE% %TIME%"

git commit -m "%MSG%"
echo.

:push
git push
echo.
if %errorlevel%==0 (
    echo === Fertig! Alles zu GitHub hochgeladen. ===
) else (
    echo === FEHLER beim Hochladen. Meldung oben lesen. ===
)
echo.
pause
