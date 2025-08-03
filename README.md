# SnapRAID
Supplemental files used for my Windows SnapRAID setup.
The original script was from [Quaraxkad](https://sourceforge.net/u/quaraxkad/profile/) on a [SnapRAID SourceForge Discussion](https://sourceforge.net/p/snapraid/discussion/1677233/thread/c7ec47b8/#575f) which I have modified as needed.

# Required
> For the timestamped logs to work properly, you must set your computers "Short Date" format to "yyyy-MM-dd". You can change this setting under "Region and Language" in the "Control Panel".

The following programs will need to be in the root of your SnapRAID directory.

[mailsend.exe](https://github.com/muquit/mailsend)

[rxrepl.exe](https://sites.google.com/site/regexreplace/)

[tee.exe](https://gnuwin32.sourceforge.net/packages/coreutils.htm) Part of GNU Core Utilities. Once installed copy `tee.exe` to your SnapRAID directory.


# daily_a##.bat
A stand-alone Windows batch file to be run daily in order to keep Data synced and checked with an emailed report when complete.

One bat file per "Array" (Config) for SnapRAID so they can run in parallel.

# TO-DO
Set up `ServicesTaskCheck` to dynamically check any other arrays that may be running on the system without it being hardcoded.

Set up `StopServices` and `StartServices` to be from the `Config` list for easier management.

# License
Shield: [![CC BY-NC 4.0][cc-by-nc-shield]][cc-by-nc]

This work is licensed under a
[Creative Commons Attribution-NonCommercial 4.0 International License][cc-by-nc].

[![CC BY-NC 4.0][cc-by-nc-image]][cc-by-nc]

[cc-by-nc]: https://creativecommons.org/licenses/by-nc/4.0/
[cc-by-nc-image]: https://licensebuttons.net/l/by-nc/4.0/88x31.png
[cc-by-nc-shield]: https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg
