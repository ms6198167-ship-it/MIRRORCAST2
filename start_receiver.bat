@echo off
cd /d "%~dp0"
py -m pip show Pillow >nul 2>&1
if errorlevel 1 (
  echo Dependencies missing. Run: py -m pip install -r requirements.txt
  pause
  exit /b 1
)
py receiver.py
pause
