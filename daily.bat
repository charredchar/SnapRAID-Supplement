@ECHO off

CHCP 65001 > nul

SET param=%~1
IF NOT "%param%"=="" (
 IF "%param%"=="skipdel" (
  ECHO Skipping Deleted File Threshold Check...
 ) ELSE IF "%param%"=="skip01" (
  ECHO Skipping Sync for Array 01...
 ) ELSE IF "%param%"=="skip02" (
  ECHO Skipping Sync for Array 02...
 ) ELSE IF "%param%"=="skipdiff" (
  ECHO Skipping Diff Check...
 ) ELSE IF "%param%"=="skipscrub" (
  ECHO Skipping Scrub Routine...
 ) ELSE (
  ECHO.
  ECHO skipdel = Skips deleted files threshold check.
  ECHO skip01 = Skips array 01.
  ECHO skip02 = Skips array 02.
  ECHO skipdiff = Skips diff check ^(and delete threshold^).
  ECHO skipscrub = Skips scrub routine^(s^).
REM  EXIT /b
  PAUSE
 )
)

:Config
REM If password has a &, escape it with ^. So pass&word = pass^&word.
SET emailserver=address
SET emailport=25
SET emailto=email@gmail.com
SET emailfrom=email@gmail.com
SET emailname=SnapRAID
SET emailtls=false
SET emailuser=username
SET emailpass=password
SET srpath=C:\SnapRAID
SET delthresh=1000
IF %emailtls%==true (SET emailstring="%srpath%\mailsend" -smtp "%emailserver%" -port "%emailport%" -starttls -user %emailuser% -pass %emailpass% -t "%emailto%" +cc +bc -f "%emailfrom%" -name "%emailname%") ELSE (SET emailstring="%srpath%\mailsend" -smtp "%emailserver%" -port "%emailport%" -t "%emailto%" +cc +bc -f "%emailfrom%" -name "%emailname%") 

REM Services to Stop

:StopServices
(ECHO. & ECHO. & ECHO [7mStopping Services...[0m & ECHO.)
REM net stop Radarr
REM net stop Sonarr
REM net stop Readarr
REM net stop Lidarr
sc \\webservices stop Radarr
sc \\webservices stop Sonarr
sc \\webservices stop Readarr
sc \\webservices stop Lidarr

REM Start SnapRAID Array 01

:CheckRunningA01
MD %srpath%\log\
IF "%param%"=="skip01" (
(ECHO. & ECHO. & ECHO [7mSkipping Array 01.[0m & ECHO.)
ECHO Skip01 was called, proceeding to Array 02.
GOTO CheckRunningA02
)
tasklist /FI "IMAGENAME eq snapraid.exe" 2>NUL | find /I /N "snapraid.exe">NUL
IF NOT "%ERRORLEVEL%"=="0" GOTO RunDiffA01
SET a01rtimestamp=%date%_%time::=;%
SET a01rtimestamp=%a01rtimestamp: =0%
(ECHO. & ECHO. & ECHO [7mCan not run task because snapraid.exe instance exists.[0m & ECHO.)
ECHO Can not run task because snapraid.exe instance exists. > "%srpath%\log\%a01rtimestamp%_sync-A01.txt" 2>&1
%emailstring% -sub "SnapRAID Already Running for Array 01" -M "Can not run task because snapraid.exe instance exists."
GOTO CheckRunningA02

:RunDiffA01
IF "%param%"=="skipdiff" (
(ECHO. & ECHO. & ECHO [7mSkipping Diff Check on Array 01.[0m & ECHO.)
SET a01dtimestamp=%date%_%time::=;%
SET a01dtimestamp=%a01dtimestamp: =0%
ECHO Diff Skipped > "%srpath%\log\%a01dtimestamp%_diff-A01.txt" 2>&1
GOTO RunSyncA01
)
(ECHO. & ECHO. & ECHO [7mRunning Diff Check on Array 01.[0m & ECHO.)
SET a01dtimestamp=%date%_%time::=;%
SET a01dtimestamp=%a01dtimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array01.conf" diff -v > "%srpath%\log\%a01dtimestamp%_diff-A01.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array01.conf" diff -v 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a01dtimestamp%_diff-A01.txt" 2>&1


findstr /r /i ".*?(\d+) removed.*" "%srpath%\log\%a01dtimestamp%_diff-A01.txt" >> "%srpath%\counts\removed.txt"
"%srpath%\rxrepl" -f "%srpath%\counts\removed.txt" -o "%srpath%\counts\removed.cnt" --no-backup --no-bom -i -s ".*?(\d+) removed\r\n.*" -r "\1"

REM "%srpath%\rxrepl" -f "%srpath%\log\%a01dtimestamp%_diff-A01.txt" -o "%srpath%\removed.cnt" --no-backup --no-bom -i -s ".*?(\d+) removed\r\n.*" -r "\1"

findstr /r /i ".*?(\d+) added.*" "%srpath%\log\%a01dtimestamp%_diff-A01.txt" >> "%srpath%\counts\added.txt"
"%srpath%\rxrepl" -f "%srpath%\counts\added.txt" -o "%srpath%\counts\added.cnt" --no-backup --no-bom -i -s ".*?(\d+) added\r\n.*" -r "\1"

REM "%srpath%\rxrepl" -f "%srpath%\log\%a01dtimestamp%_diff-A01.txt" -o "%srpath%\added.cnt" --no-backup --no-bom -i -s ".*?(\d+) added\r\n.*" -r "\1"

SET /p intrem=<"%srpath%\counts\removed.cnt"
SET /p intadd=<"%srpath%\counts\added.cnt"
DEL "%srpath%\counts\removed.txt"
DEL "%srpath%\counts\added.txt"
DEL "%srpath%\counts\removed.cnt"
DEL "%srpath%\counts\added.cnt"


:CheckRemovedA01
IF "%param%"=="skipdel" GOTO RunSyncA01
IF %intrem% GTR %delthresh% (
%emailstring% -sub "SnapRAID not running for Array 01: %intrem% files removed." -M "%a01dtimestamp%. %intrem% removed. %intadd% added." -M "Services not restarted! Sync for Array 02 not started!" -M "If removed files were expected then run daily.bat with ""skipdel""." -attach "%srpath%\log\%a01dtimestamp%_diff-A01.txt",a
REM EXIT /B 999
PAUSE
)

:RunTouchA01
IF "%param%"=="skiptouch" (
(ECHO. & ECHO. & ECHO [7mSkipping Touch on Array 01.[0m & ECHO.)
SET a01ttimestamp=%date%_%time::=;%
SET a01ttimestamp=%a01ttimestamp: =0%
ECHO Touch Skipped > "%srpath%\log\%a01ttimestamp%_touch-A01.txt" 2>&1
GOTO RunSyncA01
)
(ECHO. & ECHO. & ECHO [7mRunning Touch on Array 01.[0m & ECHO.)
SET a01ttimestamp=%date%_%time::=;%
SET a01ttimestamp=%a01ttimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array01.conf" touch -v > "%srpath%\log\%a01ttimestamp%_touch-A01.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array01.conf" touch -v 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a01ttimestamp%_touch-A01.txt" 2>&1
SET toucha01result=0
findstr /L /C:"Unexpected Windows error" "%srpath%\log\%a01ttimestamp%_touch-A01.txt"
IF %ERRORLEVEL%==0 (
SET toucha01result=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)


:RunSyncA01
(ECHO. & ECHO. & ECHO [7mRunning Sync on Array 01.[0m & ECHO.)
SET a01stimestamp=%date%_%time::=;%
SET a01stimestamp=%a01stimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array01.conf" sync -v --test-io-cache=64 > "%srpath%\log\%a01stimestamp%_sync-A01.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array01.conf" sync -v --test-io-cache=64 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a01stimestamp%_sync-A01.txt" 2>&1
SET synca01result=%ERRORLEVEL%
findstr /L /C:"Unexpected Windows error" "%srpath%\log\%a01stimestamp%_sync-A01.txt"
IF %ERRORLEVEL%==0 (
SET synca01result=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)
"%srpath%\rxrepl" -f "%srpath%\log\%a01stimestamp%_sync-A01.txt" -a --no-backup --no-bom -i -s "\d+\%%,\s+\d+\sMiB.*?\r\n" -r ""

:RunScrubNewA01
IF "%param%"=="skipscrub" (
(ECHO. & ECHO. & ECHO [7mSkipping Scrub of New Data on Array 01.[0m & ECHO.)
SET a01sntimestamp=%date%_%time::=;%
SET a01sntimestamp=%a01sntimestamp: =0%
ECHO Scrub Skipped > "%srpath%\log\%a01sntimestamp%_scrubnew-A01.txt" 2>&1
SET scrubna01result=0
GOTO RunStatusA01
)
(ECHO. & ECHO. & ECHO [7mRunning Scrub of New Data on Array 01.[0m & ECHO.)
SET a01sntimestamp=%date%_%time::=;%
SET a01sntimestamp=%a01sntimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array01.conf" scrub -p new -v --test-io-cache=64 > "%srpath%\log\%a01sntimestamp%_scrubnew-A01.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array01.conf" scrub -p new -v --test-io-cache=64 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a01sntimestamp%_scrubnew-A01.txt" 2>&1
SET scrubna01result=%ERRORLEVEL%
findstr /L /C:"Unexpected Windows error" "%srpath%\log\%a01sntimestamp%_scrubnew-A01.txt"
IF %ERRORLEVEL%==0 (
SET scrubna01result=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)
"%srpath%\rxrepl" -f "%srpath%\log\%a01sntimestamp%_scrubnew-A01.txt" -a --no-backup --no-bom -i -s "\d+\%%,\s+\d+\sMiB.*?\r\n" -r ""

:RunScrubOldA01
IF "%param%"=="skipscrub" (
(ECHO. & ECHO. & ECHO [7mSkipping Scrub of Oldest 1%% on Array 01.[0m & ECHO.)
SET a01sotimestamp=%date%_%time::=;%
SET a01sotimestamp=%a01sotimestamp: =0%
ECHO Scrub Skipped > "%srpath%\log\%a01sotimestamp%_scrubold-A01.txt" 2>&1
SET scruboa01result=0
GOTO RunStatusA01
)
(ECHO. & ECHO. & ECHO [7mRunning Scrub of Oldest 1%% on Array 01.[0m & ECHO.)
SET a01sotimestamp=%date%_%time::=;%
SET a01sotimestamp=%a01sotimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array01.conf" scrub -p 1 -o 90 -v --test-io-cache=64 > "%srpath%\log\%a01sotimestamp%_scrubold-A01.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array01.conf" scrub -p 1 -o 90 -v --test-io-cache=64 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a01sotimestamp%_scrubold-A01.txt" 2>&1
SET scruboa01result=%ERRORLEVEL%
findstr /L /C:"Unexpected Windows error" "%srpath%\log\%a01sotimestamp%_scrubold-A01.txt"
IF %ERRORLEVEL%==0 (
SET scruboa01result=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)
"%srpath%\rxrepl" -f "%srpath%\log\%a01sotimestamp%_scrubold-A01.txt" -a --no-backup --no-bom -i -s "\d+\%%,\s+\d+\sMiB.*?\r\n" -r ""

:RunStatusA01
(ECHO. & ECHO. & ECHO [7mRunning Status on Array 01.[0m & ECHO.)
SET a01sttimestamp=%date%_%time::=;%
SET a01sttimestamp=%a01sttimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array01.conf" status -v >> "%srpath%\log\%a01sttimestamp%_status-A01.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array01.conf" status -v 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a01sttimestamp%_status-A01.txt" 2>&1
SET statusa01result=%ERRORLEVEL%

:CheckStatusLogA01
SET statusa01warn=0
findstr /L /C:"WARNING" "%srpath%\log\%a01sttimestamp%_status-A01.txt"
IF %ERRORLEVEL%==0 (
SET statusa01warn=1
)

SET statusa01danger=0
findstr /L /C:"DANGER" "%srpath%\log\%a01sttimestamp%_status-A01.txt"
IF %ERRORLEVEL%==0 (
SET statusa01danger=1
)

SET statusa01good=GOOD
IF NOT %toucha01result%==0 SET statusa01good=ERROR 
IF NOT %synca01result%==0 SET statusa01good=ERROR
IF NOT %scrubna01result%==0 SET statusa01good=ERROR
IF NOT %scruboa01result%==0 SET statusa01good=ERROR
IF NOT %statusa01result%==0 SET statusa01good=ERROR
IF NOT %statusa01warn%==0 SET statusa01good=ERROR
IF NOT %statusa01danger%==0 SET statusa01good=ERROR

SET statusstring=(touch:%toucha01result%) (sync:%synca01result%)(scrub1:%scrubna01result%)(scrub2:%scruboa01result%)(status:%statusa01result%)(warn:%statusa01warn%)(danger:%statusa01danger%)
SET diffstring=(REM:%intrem%)(ADD:%intadd%)
%emailstring% -sub "SnapRAID Array 01 Status %statusa01good% %statusstring% %diffstring%" -attach "%srpath%\log\%a01sttimestamp%_status-A01.txt",text/plain,i -attach "%srpath%\log\%a01sttimestamp%_status-A01.txt",a -attach "%srpath%\log\%a01dtimestamp%_diff-A01.txt",a -attach "%srpath%\log\%a01ttimestamp%_touch-A01.txt",a -attach "%srpath%\log\%a01stimestamp%_sync-A01.txt",a -attach "%srpath%\log\%a01sntimestamp%_scrubnew-A01.txt",a -attach "%srpath%\log\%a01sotimestamp%_scrubold-A01.txt",a

REM End SnapRAID Array 01





REM Start SnapRAID Array 02

:CheckRunningA02
MD %srpath%\log\
IF "%param%"=="skip02" (
(ECHO. & ECHO. & ECHO [7mSkipping Array 02.[0m & ECHO.)
SET statusa02good=GOOD
ECHO Skip02 was called, proceeding to Finish.
GOTO StartServices
)
tasklist /FI "IMAGENAME eq snapraid.exe" 2>NUL | find /I /N "snapraid.exe">NUL
IF NOT "%ERRORLEVEL%"=="0" GOTO RunDiffA02
SET a02rtimestamp=%date%_%time::=;%
SET a02rtimestamp=%a02rtimestamp: =0%
(ECHO. & ECHO. & ECHO Can not run task because snapraid.exe instance exists & ECHO.)
ECHO Can not run task because snapraid.exe instance exists > "%srpath%\log\%a02rtimestamp%_sync-A02.txt" 2>&1
%emailstring% -sub "SnapRAID Already Running for Array 02" -M "Can not run task because snapraid.exe instance exists."
REM EXIT /B 555
PAUSE

:RunDiffA02
IF "%param%"=="skipdiff" (
(ECHO. & ECHO. & ECHO [7mSkipping Diff Check on Array 02.[0m & ECHO.)
SET a02dtimestamp=%date%_%time::=;%
SET a02dtimestamp=%a02dtimestamp: =0%
ECHO Diff Skipped > "%srpath%\log\%a02dtimestamp%_diff-A02.txt" 2>&1
GOTO RunSyncA02
)
(ECHO. & ECHO. & ECHO [7mRunning Diff Check on Array 02.[0m & ECHO.)
SET a02dtimestamp=%date%_%time::=;%
SET a02dtimestamp=%a02dtimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array02.conf" diff -v > "%srpath%\log\%a02dtimestamp%_diff-A02.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array02.conf" diff -v 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a02dtimestamp%_diff-A02.txt" 2>&1

findstr /r /i ".*?(\d+) removed.*" "%srpath%\log\%a02dtimestamp%_diff-A02.txt" >> "%srpath%\counts\removed.txt"
"%srpath%\rxrepl" -f "%srpath%\counts\removed.txt" -o "%srpath%\counts\removed.cnt" --no-backup --no-bom -i -s ".*?(\d+) removed\r\n.*" -r "\1"

REM "%srpath%\rxrepl" -f "%srpath%\log\%a02dtimestamp%_diff-A02.txt" -o "%srpath%\removed.cnt" --no-backup --no-bom -i -s ".*?(\d+) removed\r\n.*" -r "\1"

findstr /r /i ".*?(\d+) added.*" "%srpath%\log\%a02dtimestamp%_diff-A02.txt" >> "%srpath%\counts\added.txt"
"%srpath%\rxrepl" -f "%srpath%\counts\added.txt" -o "%srpath%\counts\added.cnt" --no-backup --no-bom -i -s ".*?(\d+) added\r\n.*" -r "\1"

REM "%srpath%\rxrepl" -f "%srpath%\log\%a02dtimestamp%_diff-A02.txt" -o "%srpath%\added.cnt" --no-backup --no-bom -i -s ".*?(\d+) added\r\n.*" -r "\1"

SET /p intrem=<"%srpath%\counts\removed.cnt"
SET /p intadd=<"%srpath%\counts\added.cnt"
DEL "%srpath%\counts\removed.txt"
DEL "%srpath%\counts\added.txt"
DEL "%srpath%\counts\removed.cnt"
DEL "%srpath%\counts\added.cnt"


:CheckRemovedA02
IF "%param%"=="skipdel" GOTO RunSyncA02
IF %intrem% GTR %delthresh% (
%emailstring% -sub "SnapRAID not running for Array 02: %intrem% files removed." -M "%a02dtimestamp%. %intrem% removed. %intadd% added." -M "Services not restarted!" -M "If removed files were expected then run daily.bat with ""skipdel""." -attach "%srpath%\log\%a02dtimestamp%_diff-A02.txt",a
REM EXIT /B 999
PAUSE
)

:RunTouchA02
IF "%param%"=="skiptouch" (
(ECHO. & ECHO. & ECHO [7mSkipping Touch on Array 02.[0m & ECHO.)
SET a02ttimestamp=%date%_%time::=;%
SET a02ttimestamp=%a02ttimestamp: =0%
ECHO Touch Skipped > "%srpath%\log\%a02ttimestamp%_touch-A02.txt" 2>&1
GOTO RunSyncA02
)
(ECHO. & ECHO. & ECHO [7mRunning Touch on Array 02.[0m & ECHO.)
SET a02ttimestamp=%date%_%time::=;%
SET a02ttimestamp=%a02ttimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array02.conf" touch -v > "%srpath%\log\%a02ttimestamp%_touch-A02.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array02.conf" touch -v 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a02ttimestamp%_touch-A02.txt" 2>&1
findstr /L /C:"Unexpected Windows error" "%srpath%\log\%a02ttimestamp%_touch-A02.txt"
IF %ERRORLEVEL%==0 (
SET toucha02result=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)

:RunSyncA02
(ECHO. & ECHO. & ECHO [7mRunning Sync on Array 02.[0m & ECHO.)
SET a02stimestamp=%date%_%time::=;%
SET a02stimestamp=%a02stimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array02.conf" sync -v --test-io-cache=64 > "%srpath%\log\%a02stimestamp%_sync-A02.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array02.conf" sync -v --test-io-cache=64 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a02stimestamp%_sync-A02.txt" 2>&1
SET synca02result=%ERRORLEVEL%
findstr /L /C:"Unexpected Windows error" "%srpath%\log\%a02stimestamp%_sync-A02.txt"
IF %ERRORLEVEL%==0 (
SET synca02result=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)
"%srpath%\rxrepl" -f "%srpath%\log\%a02stimestamp%_sync-A02.txt" -a --no-backup --no-bom -i -s "\d+\%%,\s+\d+\sMiB.*?\r\n" -r ""

:RunScrubNewA02
IF "%param%"=="skipscrub" (
(ECHO. & ECHO. & ECHO [7mSkipping Scrub on New Data on Array 02.[0m & ECHO.)
SET a02sntimestamp=%date%_%time::=;%
SET a02sntimestamp=%a02sntimestamp: =0%
ECHO Scrub Skipped > "%srpath%\log\%a02sntimestamp%_scrubnew-A02.txt" 2>&1
SET scrubna02result=0
GOTO RunStatusA02
)
(ECHO. & ECHO. & ECHO [7mRunning Scrub of New Data on Array 02.[0m & ECHO.)
SET a02sntimestamp=%date%_%time::=;%
SET a02sntimestamp=%a02sntimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array02.conf" scrub -p new -v --test-io-cache=64 > "%srpath%\log\%a02sntimestamp%_scrubnew-A02.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array02.conf" scrub -p new -v --test-io-cache=64 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a02sntimestamp%_scrubnew-A02.txt" 2>&1
SET scrubna02result=%ERRORLEVEL%
findstr /L /C:"Unexpected Windows error" "%srpath%\log\%a02sntimestamp%_scrubnew-A02.txt"
IF %ERRORLEVEL%==0 (
SET scrubna02result=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)
"%srpath%\rxrepl" -f "%srpath%\log\%a02sntimestamp%_scrubnew-A02.txt" -a --no-backup --no-bom -i -s "\d+\%%,\s+\d+\sMiB.*?\r\n" -r ""

:RunScrubOldA02
IF "%param%"=="skipscrub" (
SCHO Skipping Scrub of Oldest 1%% on Array 02.
SET a02sotimestamp=%date%_%time::=;%
SET a02sotimestamp=%a02sotimestamp: =0%
ECHO Scrub Skipped > "%srpath%\log\%a02sotimestamp%_scrubold-A02.txt" 2>&1
SET scruboa02result=0
GOTO RunStatusA02
)
(ECHO. & ECHO. & ECHO [7mRunning Scrub of Oldest 1%% on Array 02.[0m & ECHO.)
SET a02sotimestamp=%date%_%time::=;%
SET a02sotimestamp=%a02sotimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array02.conf" scrub -p 1 -o 90 -v --test-io-cache=64 > "%srpath%\log\%a02sotimestamp%_scrubold-A02.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array02.conf" scrub -p 1 -o 90 -v --test-io-cache=64 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a02sotimestamp%_scrubold-A02.txt" 2>&1
SET scruboa02result=%ERRORLEVEL%
findstr /L /C:"Unexpected Windows error" "%srpath%\log\%a02sotimestamp%_scrubold-A02.txt"
IF %ERRORLEVEL%==0 (
SET scruboa02result=1
(ECHO. & ECHO. & ECHO [41mError Found![0m & ECHO.)
)
"%srpath%\rxrepl" -f "%srpath%\log\%a02sotimestamp%_scrubold-A02.txt" -a --no-backup --no-bom -i -s "\d+\%%,\s+\d+\sMiB.*?\r\n" -r ""

:RunStatusA02
(ECHO. & ECHO. & ECHO [7mRunning Status on Array 02.[0m & ECHO.)
SET a02sttimestamp=%date%_%time::=;%
SET a02sttimestamp=%a02sttimestamp: =0%
REM "%srpath%\snapraid" -c "%srpath%\array02.conf" status -v >> "%srpath%\log\%a02sttimestamp%_status-A02.txt" 2>&1
"%srpath%\snapraid" -c "%srpath%\array02.conf" status -v 2>&1 | "%srpath%\tee" -i "%srpath%\log\%a02sttimestamp%_status-A02.txt" 2>&1
SET statusa02result=%ERRORLEVEL%


:CheckStatusLogA02
SET statusa02warn=0
findstr /m "WARNING" "%srpath%\log\%a02sttimestamp%_status-A02.txt"
IF %ERRORLEVEL%==0 (
SET statusa02warn=1
)

SET statusa02danger=0
findstr /m "DANGER" "%srpath%\log\%a02sttimestamp%_status-A02.txt"
IF %ERRORLEVEL%==0 (
SET statusa02danger=1
)

SET statusa02good=GOOD
IF NOT %synca02result%==0 SET statusa02good=ERROR
IF NOT %scrubna02result%==0 SET statusa02good=ERROR
IF NOT %scruboa02result%==0 SET statusa02good=ERROR
IF NOT %statusa02result%==0 SET statusa02good=ERROR
IF NOT %statusa02warn%==0 SET statusa02good=ERROR
IF NOT %statusa02danger%==0 SET statusa02good=ERROR

SET statusstring=(sync:%synca02result%)(scrub1:%scrubna02result%)(scrub2:%scruboa02result%)(status:%statusa02result%)(warn:%statusa02warn%)(danger:%statusa02danger%)
SET diffstring=(REM:%intrem%)(ADD:%intadd%)
%emailstring% -sub "SnapRAID Array 02 Status %statusa02good% %statusstring% %diffstring%" -attach "%srpath%\log\%a02sttimestamp%_status-A02.txt",text/plain,i -attach "%srpath%\log\%a02sttimestamp%_status-A02.txt",a -attach "%srpath%\log\%a02dtimestamp%_diff-A02.txt",a -attach "%srpath%\log\%a02ttimestamp%_touch-A02.txt",a -attach "%srpath%\log\%a02stimestamp%_sync-A02.txt",a -attach "%srpath%\log\%a02sntimestamp%_scrubnew-A02.txt",a -attach "%srpath%\log\%a02sotimestamp%_scrubold-A02.txt",a

REM End SnapRAID Array 02


REM Services Restart unless error

:StartServices
(ECHO. & ECHO. & ECHO [7mChecking for Errors.[0m & ECHO.)
SET statusallgood=GOOD
IF NOT %statusa01good%==GOOD SET statusallgood=ERROR
IF NOT %statusa02good%==GOOD SET statusallgood=ERROR

ECHO Array 01 %statusa01good%
ECHO Array 02 %statusa02good%

IF %statusallgood%==GOOD (
(ECHO. & ECHO. & ECHO [7mStarting Services...[0m & ECHO.)
REM net start Radarr
REM net start Sonarr
REM net start Readarr
REM net start Lidarr
sc \\webservices start Radarr
sc \\webservices start Sonarr
sc \\webservices start Readarr
sc \\webservices start Lidarr
)

IF %statusallgood%==ERROR (
(ECHO. & ECHO. & ECHO [7mServices Not Started.[0m & ECHO.)
%emailstring% -sub "SnapRAID did not restart services." -M "There was an error found during processing." -M "Array 01: %statusa01good%" -M "Array 02: %statusa02good%" -M "Check logs for further details."
)

:End

EXIT /B 0
REM PAUSE
