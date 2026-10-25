@echo off
title Running Barber Booking App on Real Device
color 0A

echo ========================================================
echo       DANG CHUAN BI CHAY APP TREN DIEN THOAI THAT
echo ========================================================
echo.

:: Chuyen thu muc lam viec ve thu muc chua file script nay
cd /d "%~dp0"

echo 1. Dang kiem tra ket noi thiet bi qua ADB...
adb devices
echo.

echo 2. Dang kiem tra danh sach thiet bi cua Flutter...
flutter devices
echo.

echo 3. Dang cap nhat thu vien...
call flutter pub get
echo.

echo ========================================================
echo   Dang build va cai dat ung dung vao dien thoai...
echo   (Qua trinh nay co the mat vai phut trong lan dau tien)
echo ========================================================
flutter run -t lib/main.dart

echo.
pause