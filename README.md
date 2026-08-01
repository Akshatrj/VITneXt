# VIT NextClass

Smart FFCS timetable manager for **VIT Bhopal** students. Manage courses, view schedules, cancel classes, and see your next class on an Android home-screen widget — fully offline.

## Features

- Visual FFCS slot picker (multi-tap timetable grid)
- Home dashboard with current/next class
- Weekly and monthly calendar views
- Mark classes as cancelled (e.g. by teacher)
- Local class reminders (configurable minutes before)
- Live class status on status bar (Android ongoing notification / live chip)
- Auto silent + vibrate during class (optional)
- Export/import JSON backup + share timetable as text
- Android home-screen widget (current/next class)

## Requirements

- Flutter SDK 3.5+
- Android device/emulator (Android-only project)

## Setup

```bash
cd vit_nextclass
flutter pub get
flutter run
```

## Build release APK

```bash
flutter build apk --release
```

For Play Store or production installs, configure release signing (see below).

## Android home-screen widget

1. Install and open the app; add your courses.
2. Long-press your Android home screen → **Widgets**.
3. Find **VIT NextClass** → drag **Shows your current or next class** onto the home screen.
4. The widget updates when you open the app and every ~60 seconds while on the home screen.
5. **Tap** the widget to open the app. **Cancel class** button marks the next class as cancelled by teacher.

## Notifications

Settings → **Notify before class** → choose 5/10/15/30 minutes. Reminders are scheduled locally for the next 7 days (skipped for cancelled/completed classes).

## Class Focus (live status + silent mode)

Settings → **Class Focus**:

- **Live class status** — ongoing notification showing your current class (status-bar live chip on supported Android 14+ devices, similar to Dynamic Island).
- **Silent + vibrate during class** — switches to vibrate-only while a class is running, then restores your previous sound mode when it ends.

Battery-friendly: uses scheduled alarms at class start/end instead of constant polling. The foreground service runs only during an active class or a short pre-class window for live status — not all day.

Privacy: fully offline, no network. Only class time slots are stored in the native monitor; course names are kept in the app and passed in-memory for notifications when you open or sync the app.

## Data

All data stays on your device (`semesters.json`, `courses.json`, etc. in app documents). Use Settings → Export/Import for backup.

## Release signing

1. Create a keystore:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `android/key.properties.example` to `android/key.properties` and fill in paths/passwords.
3. Uncomment the signing block in `android/app/build.gradle.kts`.
4. Build: `flutter build apk --release`

## Project structure

```
lib/
  core/           # models, services, FFCS grid/slots, storage
  features/       # home, weekly, calendar, manage, settings, onboarding
  widgets/        # app shell, cancel-class sheet
android/          # Kotlin widget + MethodChannel bridge
test/             # unit tests
```

## Tests

```bash
flutter test
```

## License

Private / educational use. Not affiliated with VIT Bhopal.
