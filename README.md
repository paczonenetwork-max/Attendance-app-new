# Factory Attendance App

Mobile-friendly Flutter app for factory attendance.

Features:
- Add / edit / remove workers
- Present, absent, half day, leave, weekly off
- 8-hour duty + 30-minute lunch rule
- Automatic late calculation (default shift starts 09:00)
- Automatic overtime calculation (after 17:30)
- Offline local storage
- Weekly present chart
- Daily dashboard
- Light/dark mode

## Build APK
1. Install Flutter and Android Studio.
2. Open this folder in Android Studio or VS Code.
3. Run `flutter pub get`
4. Run `flutter build apk --release`
5. APK will be in `build/app/outputs/flutter-apk/app-release.apk`

The app is designed for Android phones and uses responsive Flutter widgets.
