@echo off
REM ─── SBS Projer: Tägliches Backup einrichten ───
REM Dieses Script einmalig als Administrator ausführen!
REM Erstellt einen Windows Task Scheduler Eintrag der täglich um 12:00 das Backup ausführt

schtasks /create /tn "SBS Projer Stammdaten Backup" /tr "\"C:\Program Files\Git\bin\bash.exe\" -l -c \"cd '/d/01_SBS_Projer_GmbH/00_Entwicklung/SBS Projer DEV' && bash Datenbank/backup_stammdaten.sh\"" /sc daily /st 12:00 /f

if %errorlevel% equ 0 (
    echo.
    echo === Tägliches Backup erfolgreich eingerichtet! ===
    echo Zeitplan: Täglich um 12:00 Uhr
    echo Script:   Datenbank\backup_stammdaten.sh
    echo Backups:  Datenbank\backups\
    echo.
) else (
    echo.
    echo FEHLER: Bitte als Administrator ausführen!
    echo Rechtsklick auf setup_daily_backup.bat → "Als Administrator ausführen"
    echo.
)
pause
