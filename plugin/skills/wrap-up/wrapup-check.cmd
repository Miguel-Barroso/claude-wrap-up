@echo off
rem Windows launcher for wrapup-check.
rem
rem Windows has no shebang, so the script needs an interpreter named explicitly.
rem Each candidate is run rather than trusted by name: on Windows "python" and
rem "python3" are often the Microsoft Store's install prompt, which exists on PATH
rem and is not a Python.
rem
rem Exit codes pass through unchanged: 0 nothing needs attention, 1 something
rem does, 2 usage or config error.
setlocal enabledelayedexpansion
set "WUC_SCRIPT=%~dp0wrapup-check"
for %%I in ("py -3" python python3) do (
  set "WUC_PY=%%~I"
  !WUC_PY! -c "import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)" >nul 2>&1
  if not errorlevel 1 (
    !WUC_PY! -I "%WUC_SCRIPT%" %*
    exit /b !errorlevel!
  )
)
echo wrapup-check: no Python 3.8 or newer found; tried "py -3", "python", "python3" 1>&2
exit /b 2
