@echo off
chcp 65001 >nul
cd /d "%~dp0"
python classifier_win.py
pause
