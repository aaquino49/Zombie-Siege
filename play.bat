@echo off
cd /d "%~dp0"
if exist builds\ZombieSiege.exe (start "" builds\ZombieSiege.exe) else (godot --path game)
