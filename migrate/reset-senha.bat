@echo off
REM Duplo-clique: gera senha temporaria para um usuario (sem e-mail).
cd /d %~dp0
set /p EMAIL=Email do usuario:
node reset-password.js %EMAIL%
pause
