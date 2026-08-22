@echo off
setlocal
set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.8-hotspot"
set "ANDROID_SDK=%LOCALAPPDATA%\Android\sdk"
set "PATH=%JAVA_HOME%\bin;%ANDROID_SDK%\platform-tools;%ANDROID_SDK%\cmdline-tools\latest\bin;%PATH%"

if not exist "%ANDROID_SDK%\platforms\android-36" (
  echo Installing Android SDK packages...
  sdkmanager --sdk_root="%ANDROID_SDK%" "platform-tools" "platforms;android-36" "build-tools;35.0.0" "cmdline-tools;latest"
  echo y | sdkmanager --sdk_root="%ANDROID_SDK%" --licenses
)

cd /d "%~dp0.."
C:\src\flutter\bin\flutter.bat config --android-sdk "%ANDROID_SDK%"
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat build apk --release
echo.
echo APK: build\app\outputs\flutter-apk\app-release.apk
