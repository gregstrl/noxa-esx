@echo off
REM =====================================================================
REM  NOXA - update.bat  (Windows)
REM  Met a jour le serveur depuis GitHub (gregstrl/noxa-esx) :
REM    1) git fetch + reset --hard origin/main
REM    2) calcule le diff des ressources -> sync\state.txt
REM    3) synchronise install.sql + sql\migrations dans noxa_updater
REM  Ensuite, dans la console serveur :  noxa update
REM
REM  Le Lua serveur FiveM est sandboxe (os.execute bloque) : c'est CE
REM  script qui fait le git. La base + reload se font via `noxa update`.
REM =====================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

if "%NOXA_BRANCH%"=="" set "NOXA_BRANCH=main"

set "UPDATER=resources\noxa_updater"
set "SQL_DST=%UPDATER%\sql"
set "MIG_DST=%SQL_DST%\migrations"
set "STATE=%UPDATER%\sync\state.txt"

set "BEFORE="
set "AFTER="

REM ---------------------------------------------------------------------
REM  1) GIT
REM ---------------------------------------------------------------------
where git >nul 2>&1
if errorlevel 1 (
  echo [noxa update] git introuvable : synchro SQL seule, sans pull.
  goto :sql
)
if not exist ".git" (
  echo [noxa update] Pas de depot git : synchro SQL seule, sans pull.
  goto :sql
)

for /f "delims=" %%h in ('git rev-parse HEAD 2^>nul') do set "BEFORE=%%h"
echo [noxa update] git fetch origin %NOXA_BRANCH% ...
git fetch origin %NOXA_BRANCH%
echo [noxa update] git reset --hard origin/%NOXA_BRANCH% ...
git reset --hard origin/%NOXA_BRANCH%
for /f "delims=" %%h in ('git rev-parse HEAD 2^>nul') do set "AFTER=%%h"

if "%BEFORE%"=="%AFTER%" (
  echo [noxa update] Deja a jour ^(aucun nouveau commit^).
) else (
  echo [noxa update] Mis a jour : %BEFORE:~0,7% -^> %AFTER:~0,7%
)

REM ---------------------------------------------------------------------
REM  2) DIFF DES RESSOURCES -> state.txt
REM ---------------------------------------------------------------------
if not exist "%UPDATER%\sync" mkdir "%UPDATER%\sync"
break > "%STATE%"
if not "%BEFORE%"=="" if not "%AFTER%"=="" if not "%BEFORE%"=="%AFTER%" (
  for /f "tokens=2 delims=/" %%r in ('git diff --name-only %BEFORE% %AFTER% -- resources/ ^| findstr /b "resources/noxa_ resources/es_extended"') do (
    set "RNAME=%%r"
    if not "!RNAME!"=="noxa_updater" (
      if exist "resources\!RNAME!\" (
        >>"%STATE%" echo M !RNAME!
      ) else (
        >>"%STATE%" echo D !RNAME!
      )
    )
  )
  REM deduplication simple
  if exist "%STATE%" (
    sort "%STATE%" /unique > "%STATE%.tmp" 2>nul && move /y "%STATE%.tmp" "%STATE%" >nul
    echo [noxa update] Ressources changees :
    type "%STATE%"
  )
) else (
  echo [noxa update] Pas de diff ressources ^(reload global noxa_* cote serveur^).
)

:sql
REM ---------------------------------------------------------------------
REM  3) SYNCHRO SQL (racine -> noxa_updater\sql)
REM ---------------------------------------------------------------------
echo [noxa update] Synchronisation du SQL dans %SQL_DST% ...
if not exist "%MIG_DST%" mkdir "%MIG_DST%"
if exist "install.sql" (
  copy /y "install.sql" "%SQL_DST%\install.sql" >nul
) else (
  echo [noxa update] ERREUR : install.sql introuvable a la racine !
)

del /q "%MIG_DST%\*.sql" 2>nul
break > "%SQL_DST%\migrations.index"
if exist "sql\migrations" (
  for /f "delims=" %%f in ('dir /b /a-d /on "sql\migrations\*.sql" 2^>nul') do (
    copy /y "sql\migrations\%%f" "%MIG_DST%\%%f" >nul
    >>"%SQL_DST%\migrations.index" echo %%f
  )
)
echo [noxa update] SQL synchronise ^(install.sql + migrations^).

echo.
echo [noxa update] OK. Dans la console serveur, tape maintenant :
echo     noxa update
echo    ^(synchronise la base puis recharge les ressources modifiees^).
endlocal
