@echo off
set PATH=%PATH%;C:\flutter\bin
echo === Flutter pub get ===
call flutter pub get
echo === Launching in Chrome ===
call flutter run -d chrome --web-port 8080
pause
