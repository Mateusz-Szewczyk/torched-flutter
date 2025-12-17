@echo off
chcp 65001 >nul
echo ============================================
echo COMPLETE FIX - Downgrade Freezed 3.x to 2.x
echo ============================================
echo.
echo [1/5] Cleaning Flutter cache...
call flutter clean
if errorlevel 1 (
    echo ERROR: flutter clean failed!
    pause
    exit /b 1
)
echo Done!
echo.

echo [2/5] Removing corrupted freezed files...
if exist lib\models\models.freezed.dart del /F /Q lib\models\models.freezed.dart
if exist lib\models\models.g.dart del /F /Q lib\models\models.g.dart
echo Done!
echo.

echo [3/5] Updating dependencies (Freezed 2.4.6)...
call flutter pub get
if errorlevel 1 (
    echo ERROR: flutter pub get failed!
    pause
    exit /b 1
)
echo Done!
echo.

echo [4/5] Generating models (this will take 2-3 minutes)...
call flutter pub run build_runner build --delete-conflicting-outputs
if errorlevel 1 (
    echo ERROR: build_runner failed!
    pause
    exit /b 1
)
echo Done!
echo.

echo [5/5] Verification...
if exist lib\models\models.freezed.dart (
    echo [OK] models.freezed.dart generated successfully
) else (
    echo [ERROR] models.freezed.dart was NOT generated!
    pause
    exit /b 1
)

if exist lib\models\models.g.dart (
    echo [OK] models.g.dart generated successfully
) else (
    echo [ERROR] models.g.dart was NOT generated!
    pause
    exit /b 1
)
echo.

echo ============================================
echo SUCCESS! Now run: flutter run -d chrome
echo ============================================
echo.
pause

