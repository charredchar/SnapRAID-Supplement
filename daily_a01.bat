@ECHO off

CHCP 65001 > nul

SET param=%~1
IF NOT "%param%"=="" (
 IF "%param%"=="skipdel" (
  ECHO Skipping Deleted File Threshold Check...
 ) ELSE IF "%param%"=="skipsync" (
  ECHO Skipping Sync...
 ) ELSE IF "%param%"=="skipdiff" (
  ECHO Skipping Diff Check...
 ) ELSE IF "%param%"=="skipscrub" (
  ECHO Skipping Scrub Routine...
 ) ELSE IF "%param%"=="skipscrubnew" (
  ECHO Skipping Scrub New Routine...
 ) ELSE IF "%param%"=="skipscrubold" (
  ECHO Skipping Scrub Oldest 1%% Routine...
 ) ELSE IF "%param%"=="skipservices" (
  ECHO Skipping Restarting Services...
 ) ELSE (
  ECHO.
  ECHO skipdel = Skips deleted files threshold check.
  ECHO skipsync = Skips sync routine.
  ECHO skipdiff = Skips diff check ^(and delete threshold^).
  ECHO skipscrub = Skips scrub routine^(s^).
  ECHO skipscrubnew = Skips scrubbing new data.
  ECHO skipscrubold = Skips scrubbing oldest 1%% data.
  ECHO skipservices = Skips restarting services.
  ECHO Press any key to exit . . .
  PAUSE >null
  EXIT /b
 )
)


:Config
REM If emailpass has a &, escape it with ^. So pass&word = pass^&word.
REM Set iocache between 3 and 128, default is 8 MiB of blocks
SET emailserver=address
SET emailport=25
SET emailto=email@gmail.com
SET emailfrom=email@gmail.com
SET emailname=SnapRAID
SET emailtls=false
SET emailuser=user
SET emailpass=pass
SET srpath=C:\SnapRAID
SET friendlyname=Array 01
SET shortname=a01
SET config=array01.conf
SET delthresh=1000
SET iocache=128
SET debug=true


:Setup
IF %emailtls%==true (SET emailstring="%srpath%\mailsend" -smtp "%emailserver%" -port "%emailport%" -starttls -user %emailuser% -pass %emailpass% -t "%emailto%" +cc +bc -f "%emailfrom%" -name "%emailname%") ELSE (SET emailstring="%srpath%\mailsend" -smtp "%emailserver%" -port "%emailport%" -t "%emailto%" +cc +bc -f "%emailfrom%" -name "%emailname%") 
(ECHO. & ECHO. & ECHO [7mSetting up files and folders for %friendlyname%.[0m & ECHO.)
ECHO Checking support folders and files
MD "%srpath%\%friendlyname%\dailylog\"
MD "%srpath%\%friendlyname%\counts\"
MD "%srpath%\%friendlyname%\running\"
IF EXIST "%srpath%\%friendlyname%\running\runcheck-%shortname%.txt" ECHO A file %srpath%\%friendlyname%\running\runcheck-%shortname%.txt already exists.
IF NOT EXIST "%srpath%\%friendlyname%\running\runcheck-%shortname%.txt" ECHO FALSE > "%srpath%\%friendlyname%\running\runcheck-%shortname%.txt"


:CheckRunning
(ECHO. & ECHO. & ECHO [7mChecking if SnapRAID for %friendlyname% is already running.[0m & ECHO.)
findstr /L /C:"FALSE" "%srpath%\%friendlyname%\running\runcheck-%shortname%.txt" >nul
IF %debug%==true ( ECHO Error Level for task search is %ERRORLEVEL% )
IF "%ERRORLEVEL%"=="0" ( ECHO SnapRAID for %friendlyname% not running & GOTO SetRunning )
SET rtimestamp=%date%_%time::=;%
SET rtimestamp=%rtimestamp: =0%
(ECHO. & ECHO. & ECHO [41mCan not run task because SnapRAID for %friendlyname% is running.[0m & ECHO.)
ECHO Can not run task because SnapRAID for %friendlyname% is running. > "%srpath%\%friendlyname%\dailylog\%rtimestamp%_sync-%shortname%.txt" 2>&1
%emailstring% -sub "SnapRAID Already Running for %friendlyname%" -M "Can not run task because SnapRAID for %friendlyname% is running. Check the server to continue or halt sync."
ECHO Close the window to stop, press any key to continue . . .
PAUSE >null


:SetRunning
(ECHO. & ECHO. & ECHO [7mSetting status to running...[0m & ECHO.)
ECHO TRUE > "%srpath%\%friendlyname%\running\runcheck-%shortname%.txt"
ECHO RunCheck file set to TRUE


:StopServices
(ECHO. & ECHO. & ECHO [7mStopping Services...[0m & ECHO.)
sc \\webservices stop Radarr
sc \\webservices stop Sonarr
sc \\webservices stop Readarr
sc \\webservices stop Lidarr
sc \\webservices stop Bazarr


:RunDiff
IF "%param%"=="skipdiff" (
(ECHO. & ECHO. & ECHO [7mSkipping Diff Check on %friendlyname%.[0m & ECHO.)
SET dtimestamp=%date%_%time::=;%
SET dtimestamp=%dtimestamp: =0%
ECHO Diff Skipped > "%srpath%\%friendlyname%\dailylog\%dtimestamp%_diff-%shortname%.txt" 2>&1
ECHO skipdiff was called, proceeding to Sync
GOTO RunSync
)
(ECHO. & ECHO. & ECHO [7mRunning Diff Check on %friendlyname%.[0m & ECHO.)
SET dtimestamp=%date%_%time::=;%
SET dtimestamp=%dtimestamp: =0%
"%srpath%\snapraid" -c "%srpath%\%config%" diff -v 2>&1 | "%srpath%\tee" -i "%srpath%\%friendlyname%\dailylog\%dtimestamp%_diff-%shortname%.txt" 2>&1
IF %debug%==true ( ECHO Error Level for Diff is %ERRORLEVEL% )
findstr /r /i ".*?(\d+) removed.*" "%srpath%\%friendlyname%\dailylog\%dtimestamp%_diff-%shortname%.txt" >> "%srpath%\%friendlyname%\counts\removed.txt"
"%srpath%\rxrepl" -f "%srpath%\%friendlyname%\counts\removed.txt" -o "%srpath%\%friendlyname%\counts\removed.cnt" --no-backup --no-bom -i -s ".*?(\d+) removed\r\n.*" -r "\1"
IF %debug%==true ( ECHO Error Level for removed search is %ERRORLEVEL% )
findstr /r /i ".*?(\d+) added.*" "%srpath%\%friendlyname%\dailylog\%dtimestamp%_diff-%shortname%.txt" >> "%srpath%\%friendlyname%\counts\added.txt"
"%srpath%\rxrepl" -f "%srpath%\%friendlyname%\counts\added.txt" -o "%srpath%\%friendlyname%\counts\added.cnt" --no-backup --no-bom -i -s ".*?(\d+) added\r\n.*" -r "\1"
IF %debug%==true ( ECHO Error Level added search is %ERRORLEVEL% )
SET /p intrem=<"%srpath%\%friendlyname%\counts\removed.cnt"
SET /p intadd=<"%srpath%\%friendlyname%\counts\added.cnt"
DEL "%srpath%\%friendlyname%\counts\removed.txt"
DEL "%srpath%\%friendlyname%\counts\added.txt"
DEL "%srpath%\%friendlyname%\counts\removed.cnt"
DEL "%srpath%\%friendlyname%\counts\added.cnt"
IF %debug%==true ( ECHO Error Level for diff file management is %ERRORLEVEL% )


:CheckRemoved
IF "%param%"=="skipdel" GOTO RunTouch
IF %intrem% GTR %delthresh% (
%emailstring% -sub "SnapRAID not running for %friendlyname%: %intrem% files removed." -M "%dtimestamp%. %intrem% removed. %intadd% added." -M "Services not restarted!" -M "If removed files were expected then check the server for the console waiting to resume or run ""daily_%shortname%.bat skipdel""." -attach "%srpath%\%friendlyname%\dailylog\%dtimestamp%_diff-%shortname%.txt",a
ECHO SnapRAID did not sync, %intrem% removed, threshold set to %delthresh%. %intadd% added.
ECHO Close the window to stop, press any key to continue . . .
PAUSE >null
)

:RunTouch
IF "%param%"=="skiptouch" (
(ECHO. & ECHO. & ECHO [7mSkipping Touch on %friendlyname%.[0m & ECHO.)
SET ttimestamp=%date%_%time::=;%
SET ttimestamp=%ttimestamp: =0%
ECHO Touch Skipped > "%srpath%\%friendlyname%\dailylog\%ttimestamp%_touch-%shortname%.txt" 2>&1
ECHO skiptouch was called, proceeding to Sync
GOTO RunSync
)
(ECHO. & ECHO. & ECHO [7mRunning Touch on %friendlyname%.[0m & ECHO.)
SET ttimestamp=%date%_%time::=;%
SET ttimestamp=%ttimestamp: =0%
"%srpath%\snapraid" -c "%srpath%\%config%" touch -v 2>&1 | "%srpath%\tee" -i "%srpath%\%friendlyname%\dailylog\%ttimestamp%_touch-%shortname%.txt" 2>&1
SET touchresult=0
IF %debug%==true ( ECHO Error Level for Touch is %ERRORLEVEL% )
findstr /L /C:"Unexpected Windows error" "%srpath%\%friendlyname%\dailylog\%ttimestamp%_touch-%shortname%.txt"
IF %debug%==true ( ECHO Error Level for Unexpected Windows Error Check is %ERRORLEVEL%, 1 if not found )
IF %ERRORLEVEL%==0 (
SET touchresult=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)


:RunSync
IF "%param%"=="skipsync" (
(ECHO. & ECHO. & ECHO [7mSkipping Sync for %friendlyname%.[0m & ECHO.)
ECHO skipsync was called, proceeding to Scrub
GOTO RunScrub
)
(ECHO. & ECHO. & ECHO [7mRunning Sync on %friendlyname%.[0m & ECHO.)
SET stimestamp=%date%_%time::=;%
SET stimestamp=%stimestamp: =0%
"%srpath%\snapraid" -c "%srpath%\%config%" sync -v --test-io-cache=%iocache% 2>&1 | "%srpath%\tee" -i "%srpath%\%friendlyname%\dailylog\%stimestamp%_sync-%shortname%.txt" 2>&1
SET syncresult=%ERRORLEVEL%
IF %debug%==true ( ECHO Error Level for Sync is %ERRORLEVEL% )
findstr /L /C:"Unexpected Windows error" "%srpath%\%friendlyname%\dailylog\%stimestamp%_sync-%shortname%.txt"
IF %debug%==true ( ECHO Error Level for Unexpected Windows Error Check is %ERRORLEVEL%, 1 if not found )
IF %ERRORLEVEL%==0 (
SET syncresult=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)
"%srpath%\rxrepl" -f "%srpath%\%friendlyname%\dailylog\%stimestamp%_sync-%shortname%.txt" -a --no-backup --no-bom -c -s "\d+\%%,\s+\d+\sMB.*?\r" -r ""

:RunScrub
IF "%param%"=="skipscrub" (
(ECHO. & ECHO. & ECHO [7mSkipping Scrub of New and Oldest 1%% Data on %friendlyname%.[0m & ECHO.)
SET sntimestamp=%date%_%time::=;%
SET sntimestamp=%sntimestamp: =0%
ECHO Scrub Skipped > "%srpath%\%friendlyname%\dailylog\%sntimestamp%_scrubnew-%shortname%.txt" 2>&1
ECHO Scrub Skipped > "%srpath%\%friendlyname%\dailylog\%sotimestamp%_scrubold-%shortname%.txt" 2>&1
SET scrubnresult=0
SET scruboresult=0
ECHO skipscrub was called, proceeding to Status
GOTO RunStatus
)

:RunScrubNew
IF "%param%"=="skipscrubnew" (
(ECHO. & ECHO. & ECHO [7mSkipping Scrub of New Data on %friendlyname%.[0m & ECHO.)
SET sntimestamp=%date%_%time::=;%
SET sntimestamp=%sntimestamp: =0%
ECHO Scrub Skipped > "%srpath%\%friendlyname%\dailylog\%sntimestamp%_scrubnew-%shortname%.txt" 2>&1
SET scrubnresult=0
ECHO skipscrubnew was called, proceeding to Scrub Oldest 1%%
GOTO RunScrubOld
)
(ECHO. & ECHO. & ECHO [7mRunning Scrub of New Data on %friendlyname%.[0m & ECHO.)
SET sntimestamp=%date%_%time::=;%
SET sntimestamp=%sntimestamp: =0%
"%srpath%\snapraid" -c "%srpath%\%config%" scrub -p new -v --test-io-cache=%iocache% 2>&1 | "%srpath%\tee" -i "%srpath%\%friendlyname%\dailylog\%sntimestamp%_scrubnew-%shortname%.txt" 2>&1
SET scrubnresult=%ERRORLEVEL%
IF %debug%==true ( ECHO Error Level for Scrub New is %ERRORLEVEL% )
findstr /L /C:"Unexpected Windows error" "%srpath%\%friendlyname%\dailylog\%sntimestamp%_scrubnew-%shortname%.txt"
IF %debug%==true ( ECHO Error Level for Unexpected Windows Error Check is %ERRORLEVEL%, 1 if not found )
IF %ERRORLEVEL%==0 (
SET scrubnresult=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)
"%srpath%\rxrepl" -f "%srpath%\%friendlyname%\dailylog\%sntimestamp%_scrubnew-%shortname%.txt" -a --no-backup --no-bom -c -s "\d+\%%,\s+\d+\sMB.*?\r" -r ""


:RunScrubOld
IF "%param%"=="skipscrubold" (
(ECHO. & ECHO. & ECHO [7mSkipping Scrub of Oldest 1%% on %friendlyname%.[0m & ECHO.)
SET sotimestamp=%date%_%time::=;%
SET sotimestamp=%sotimestamp: =0%
ECHO Scrub Skipped > "%srpath%\%friendlyname%\dailylog\%sotimestamp%_scrubold-%shortname%.txt" 2>&1
SET scruboresult=0
ECHO skipscrubold was called, proceeding to Status
GOTO RunStatus
)
(ECHO. & ECHO. & ECHO [7mRunning Scrub of Oldest 1%% on %friendlyname%.[0m & ECHO.)
SET sotimestamp=%date%_%time::=;%
SET sotimestamp=%sotimestamp: =0%
"%srpath%\snapraid" -c "%srpath%\%config%" scrub -p 1 -o 90 -v --test-io-cache=%iocache% 2>&1 | "%srpath%\tee" -i "%srpath%\%friendlyname%\dailylog\%sotimestamp%_scrubold-%shortname%.txt" 2>&1
SET scruboresult=%ERRORLEVEL%
IF %debug%==true ( ECHO Error Level for Scrub Old is %ERRORLEVEL% )
findstr /L /C:"Unexpected Windows error" "%srpath%\%friendlyname%\dailylog\%sotimestamp%_scrubold-%shortname%.txt"
IF %debug%==true ( ECHO Error Level for Unexpected Windows Error Check is %ERRORLEVEL%, 1 if not found )
IF %ERRORLEVEL%==0 (
SET scruboresult=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)
"%srpath%\rxrepl" -f "%srpath%\%friendlyname%\dailylog\%sotimestamp%_scrubold-%shortname%.txt" -a --no-backup --no-bom -c -s "\d+\%%,\s+\d+\sMB.*?\r" -r ""


:RunStatus
(ECHO. & ECHO. & ECHO [7mRunning Status on %friendlyname%.[0m & ECHO.)
SET sttimestamp=%date%_%time::=;%
SET sttimestamp=%sttimestamp: =0%
"%srpath%\snapraid" -c "%srpath%\%config%" status -v 2>&1 | "%srpath%\tee" -i "%srpath%\%friendlyname%\dailylog\%sttimestamp%_status-%shortname%.txt" 2>&1
SET statusresult=%ERRORLEVEL%
IF %debug%==true ( ECHO Error Level for Status is %ERRORLEVEL% )


:ErrorCheck
(ECHO. & ECHO. & ECHO [7mChecking for Errors.[0m & ECHO.)

SET statuswarn=0
findstr /L /C:"WARNING" "%srpath%\%friendlyname%\dailylog\%sttimestamp%_status-%shortname%.txt"
IF %debug%==true ( ECHO Error Level for Warning Checks is %ERRORLEVEL%, 1 if not found )
IF %ERRORLEVEL%==0 (
SET statuswarn=1
)

SET statusdanger=0
findstr /L /C:"DANGER" "%srpath%\%friendlyname%\dailylog\%sttimestamp%_status-%shortname%.txt"
IF %debug%==true ( ECHO Error Level for Danger Check is %ERRORLEVEL%, 1 if not found )
IF %ERRORLEVEL%==0 (
SET statusdanger=1
)

SET finishstatus=GOOD
IF NOT %touchresult%==0 SET finishstatus=ERROR 
IF NOT %syncresult%==0 SET finishstatus=ERROR
IF NOT %scrubnresult%==0 SET finishstatus=ERROR
IF NOT %scruboresult%==0 SET finishstatus=ERROR
IF NOT %statusresult%==0 SET finishstatus=ERROR
IF NOT %statuswarn%==0 SET finishstatus=ERROR
IF NOT %statusdanger%==0 SET finishstatus=ERROR

ECHO %friendlyname% %finishstatus%.

IF %finishstatus%==GOOD (
(ECHO. & ECHO. & ECHO [7mSetting status to not running...[0m & ECHO.)
ECHO FALSE > "%srpath%\%friendlyname%\running\runcheck-%shortname%.txt"
ECHO RunCheck file set to FALSE
GOTO ServicesTaskCheck
)

IF %finishstatus%==ERROR (
(ECHO. & ECHO. & ECHO [41mErrors Found![0m & ECHO.)
GOTO EmailResults
)

REM End SnapRAID


REM Services Restart

:ServicesTaskCheck
IF "%param%"=="skipservices" (
(ECHO. & ECHO. & ECHO [7mSkipping Service Restart on %friendlyname%.[0m & ECHO.)
SET stctimestamp=%date%_%time::=;%
SET stctimestamp=%stctimestamp: =0%
ECHO Restarting Services Skipped > "%srpath%\%friendlyname%\dailylog\%stctimestamp%_service-%shortname%.txt" 2>&1
SET servicesrestart=0
ECHO skipservices was called, proceeding to Email Results
GOTO EmailResults
)
(ECHO. & ECHO. & ECHO [7mChecking if SnapRAID is running.[0m & ECHO.)
findstr /L /C:"FALSE" "%srpath%\Array 01\running\runcheck-a01.txt" >nul
SET checka01=%ERRORLEVEL%
IF %debug%==true ( ECHO Error Level for task search is %ERRORLEVEL% )
findstr /L /C:"FALSE" "%srpath%\Array 02\running\runcheck-a02.txt" >nul
SET checka02=%ERRORLEVEL%
IF %debug%==true ( ECHO Error Level for task search is %ERRORLEVEL% )
findstr /L /C:"FALSE" "%srpath%\Array 03\running\runcheck-a03.txt" >nul
SET checka03=%ERRORLEVEL%
IF %debug%==true ( ECHO Error Level for task search is %ERRORLEVEL% )
SET checktask=0
tasklist /FI "IMAGENAME eq snapraid.exe" 2>NUL | find /I /N "snapraid.exe">NUL
IF "%ERRORLEVEL%"=="0" SET checktask=1
IF %debug%==true ( ECHO Error Level for task search is %ERRORLEVEL%, 1 if not found )

SET taskcheck=GOOD
IF NOT %checka01%==0 SET taskcheck=ERROR 
IF NOT %checka02%==0 SET taskcheck=ERROR
IF NOT %checka03%==0 SET taskcheck=ERROR
IF NOT %checktask%==0 SET taskcheck=ERROR

IF %taskcheck%==GOOD (
GOTO StartServices
)
SET stctimestamp=%date%_%time::=;%
SET stctimestamp=%stctimestamp: =0%
ECHO Can not start services because snapraid.exe instance exists.
ECHO Can not start services %taskcheck% %checka01% %checka02% %checka03% %checktask% > "%srpath%\%friendlyname%\dailylog\%stctimestamp%_service-%shortname%.txt" 2>&1
SET servicesrestart=0
GOTO EmailResults


:StartServices
IF %finishstatus%==GOOD (
(ECHO. & ECHO. & ECHO [7mStarting Services...[0m & ECHO.)
ECHO Radarr:
sc \\webservices start Radarr | findstr /c:"STATE"
TIMEOUT /T 2 > nul
ECHO Sonarr:
sc \\webservices start Sonarr | findstr /c:"STATE"
TIMEOUT /T 2 > nul
ECHO Readarr:
sc \\webservices start Readarr | findstr /c:"STATE"
TIMEOUT /T 2 > nul
ECHO Lidarr:
sc \\webservices start Lidarr | findstr /c:"STATE"
TIMEOUT /T 2 > nul
ECHO Bazarr:
sc \\webservices start Bazarr | findstr /c:"STATE"

(ECHO. & ECHO. & ECHO Waiting for Services to start. & ECHO.)
TIMEOUT /T 10
(ECHO. & ECHO. & ECHO Checking Services. & ECHO.)
ECHO Radarr:
sc \\webservices query Radarr | findstr /c:"STATE"
TIMEOUT /T 2 > nul
ECHO Sonarr:
sc \\webservices query Sonarr | findstr /c:"STATE"
TIMEOUT /T 2 > nul
ECHO Readarr:
sc \\webservices query Readarr | findstr /c:"STATE"
TIMEOUT /T 2 > nul
ECHO Lidarr:
sc \\webservices query Lidarr | findstr /c:"STATE"
TIMEOUT /T 2 > nul
ECHO Bazarr:
sc \\webservices query Bazarr | findstr /c:"STATE"
SET servicesrestart=1
)


:EmailResults
SET statusstring=(services:%servicesrestart%) (touch:%touchresult%) (sync:%syncresult%)(scrub1:%scrubnresult%)(scrub2:%scruboresult%)(status:%statusresult%)(warn:%statuswarn%)(danger:%statusdanger%)
SET diffstring=(REM:%intrem%)(ADD:%intadd%)
%emailstring% -sub "SnapRAID %friendlyname% Status %finishstatus% %statusstring% %diffstring%" -attach "%srpath%\%friendlyname%\dailylog\%sttimestamp%_status-%shortname%.txt",text/plain,i -attach "%srpath%\%friendlyname%\dailylog\%sttimestamp%_status-%shortname%.txt",a -attach "%srpath%\%friendlyname%\dailylog\%stctimestamp%_service-%shortname%.txt",a -attach "%srpath%\%friendlyname%\dailylog\%dtimestamp%_diff-%shortname%.txt",a -attach "%srpath%\%friendlyname%\dailylog\%ttimestamp%_touch-%shortname%.txt",a -attach "%srpath%\%friendlyname%\dailylog\%stimestamp%_sync-%shortname%.txt",a -attach "%srpath%\%friendlyname%\dailylog\%sntimestamp%_scrubnew-%shortname%.txt",a -attach "%srpath%\%friendlyname%\dailylog\%sotimestamp%_scrubold-%shortname%.txt",a


:End

IF %debug%==true ( ECHO. & ECHO. & ECHO Paused due to Debug being enabled & ECHO Press any key to exit & PAUSE >null )
EXIT /B 0
