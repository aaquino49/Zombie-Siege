@echo off
cd /d "%~dp0"
title Zombie Siege - supervisor
pythonw orchestrator\supervisor.py
