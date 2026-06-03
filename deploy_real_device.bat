@echo off
echo === FalconLog - Preparing for Real Device Deployment ===
echo.

echo [1/5] Cleaning Flutter build cache...
flutter clean

echo.
echo [2/5] Getting dependencies...
flutter pub get

echo.
echo [3/5] Cleaning Android build...
cd android
.\gradlew clean
cd ..

echo.
echo [4/5] Checking Flutter doctor...
flutter doctor

echo.
echo [5/5] Building for real device...
echo Choose build type:
echo 1. Debug build (flutter run)
echo 2. Release build (flutter build apk --release)
echo 3. Profile build (flutter run --profile)
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" (
    echo Running debug build on connected device...
    flutter run
) else if "%choice%"=="2" (
    echo Building release APK...
    flutter build apk --release
    echo.
    echo APK built successfully!
    echo Location: build\app\outputs\flutter-apk\app-release.apk
) else if "%choice%"=="3" (
    echo Running profile build...
    flutter run --profile
) else (
    echo Invalid choice. Running debug build...
    flutter run
)

echo.
echo === Deployment completed! ===
pause
