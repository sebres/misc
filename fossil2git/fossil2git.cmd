@rem -----------------------------------
@rem fossil2git 
@rem script to export fossil and import in git incremental.
@rem 
@rem Usage:
@rem   fossil2git ?--f2g-clean?
@rem   fossil2git ?--force?
@rem -----------------------------------

cd /d %~dp0

@rem -- export once:
@rem fossil export --git | git fast-import
@rem -----------------------------------

@if "%1" neq "--f2g-clean" goto start
@rem -- export incremental initial (or clean-up):

del .git\.fossil2git-fssl .git\.fossil2git-git
touch .git\.fossil2git-fssl .git\.fossil2git-git

@echo Clean: [OK]
@echo Use fossil2git ?--force? to reimport ...
@goto done

@rem -----------------------------------

:start

@set fosexp=fossil

@rem -- export incremental -- with filter:
%fosexp% export --git --import-marks .git/.fossil2git-fssl --export-marks .git/.fossil2git-fssl.tmp ^
 | tclsh fossil-filter.tcl ^
 | git fast-import %* --import-marks=.git/.fossil2git-git --export-marks=.git/.fossil2git-git.tmp

@if %ERRORLEVEL% neq 0 goto error
@if exist .git\.fossil2git-fssl.tmp (
  @rem ok
) else (
  @echo ERROR: '.git\.fossil2git-fssl.tmp' does not exists ...
  @goto error
)
@if exist .git\.fossil2git-git.tmp (
  @rem ok
) else (
  @echo [ERROR] '.git\.fossil2git-git.tmp' does not exists ...
  @goto error
)
@echo Export successful - save marks now ...
del .git\.fossil2git-fssl .git\.fossil2git-git
rename .git\.fossil2git-fssl.tmp .fossil2git-fssl
rename .git\.fossil2git-git.tmp .fossil2git-git

@echo [OK]
@goto done

:error
@echo ERROR: Something goes wrong...
pause

:done
