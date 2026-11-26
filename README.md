# TripMate

TripMate records car trips. While a trip runs it shows your speed on a speedometer dial (with the number), your location, altitude, distance and time, and a small map of your route. Finished trips are saved on the phone so you can look back at average speed, max speed, max altitude and more.

- App name: **TripMate**
- Package / bundle id: **com.tripmate**
- Platforms: Android 7.0+ (API 24) and iOS 15+
- Framework: Flutter (Dart)

---

## Features

| Area | What it does |
|---|---|
| First launch | Create a 4 digit PIN (enter it twice). No mobile number, OTP or account |
| Login | Enter the 4 digit PIN every time the app opens. It unlocks as soon as the 4th digit is typed |
| PIN | Change it from the menu (top right). **Lock** returns to the PIN screen (a running trip keeps recording). Stored only as a salted hash in the Android Keystore / iOS Keychain. 5 wrong tries lock the PIN screen for 30 seconds |
| Forgot PIN | Erases the trips saved on this phone and lets you create a new PIN (there is no account to recover it from) |
| Orientation | Portrait only, on phones and tablets |
| Start trip | Asks for a name (default `Trip1`, `Trip2`, ... with the start date and time shown), then opens the live view |
| Live view | Speedometer dial + numeric speed, latitude, longitude, altitude, distance, max and average speed, elapsed time, and a square route map in the bottom right corner |
| Background | Keeps recording when the screen is off or you switch apps (Android foreground service with a notification, iOS background location) |
| Sampling | Location every 3 seconds. Below 30% battery it switches to every 10 seconds |
| Low battery | Below 30% an alert asks you to charge. It has an OK button and closes itself after 10 seconds |
| Stop trip | From the Home screen or the live view. Stops automatically after 2 hours without movement |
| History | Your last 10 trips. Tap one for details, then use Prev trip / Next trip |
| Trip details | Start location, stop location, distance covered, average speed, max speed, max altitude, plus duration and a route map. Below that, two line graphs over the whole trip: **speed** (with the average speed as a dashed red line) and **altitude**. Rename with the pencil icon |
| Storage | Local SQLite database inside the app (`tripmate.db`) |

---

## Project layout

```
lib/
  main.dart                  App start
  app.dart                   MaterialApp, low battery alert and auto-stop notice
  config.dart                All tunable values (intervals, thresholds)
  theme.dart                 Colour palette and theme
  models/trip.dart           Trip and TrackPoint
  data/trip_database.dart    SQLite (sqflite)
  services/
    session_store.dart       Hashed PIN, lockout and unlock state in secure storage
    sampling.dart            3 s / 10 s sampling rule
    trip_tracker.dart        Location sampling, battery rules, idle auto-stop
    services.dart            Creates the services at start-up
  screens/                   PIN setup, PIN login, home, live trip, history, details
  widgets/                   Speedometer and line graphs (CustomPainter), route map, logo, timed alert
tool/make_icons.py           Regenerates the launcher icon PNGs
```

No images are bundled. The logo, speedometer and icons are drawn in code or as small vector files. Map tiles are downloaded only while a map is on screen.

Packages used (kept to a minimum): `geolocator`, `battery_plus`, `sqflite`, `path`, `flutter_map`, `latlong2`, `geocoding`, `flutter_secure_storage`, `crypto`, `intl`. The graphs are drawn in code, so no chart package is needed.

---

## 1. Set up your computer

1. Install **Flutter 3.50 or newer** (stable): https://docs.flutter.dev/get-started/install. This project needs Dart 3.14.
2. Install **VS Code** and the **Flutter** extension (VS Code will suggest it when you open the folder).
3. For Android: install **Android Studio** (for the Android SDK and an emulator). Run `flutter doctor --android-licenses`.
4. For iOS (Mac only): install **Xcode** from the App Store, then run `sudo xcode-select --switch /Applications/Xcode.app` and open Xcode once.
5. Check everything with `flutter doctor`.

## 2. Open and run in VS Code

1. **File > Open Folder** and choose the `TripMate` folder.
2. In a terminal inside VS Code run:
   ```
   flutter pub get
   ```
3. Start an emulator or plug in a phone (pick it in the bottom right of VS Code).
4. Press **F5** and choose **TripMate**. On first launch the app asks you to create a 4 digit PIN.

> Tip: location is easiest to test on a real phone in a car. On the Android emulator use **Extended controls > Location > Routes** to play back a route. On the iOS Simulator use **Features > Location > Freeway Drive**.

Command line equivalents:
```
flutter run       # run on the selected device
flutter test      # unit tests
flutter analyze   # lints
```

## 3. Build for release

### Android (Play Store)

1. Create an upload key (once):
   ```
   keytool -genkey -v -keystore ~/tripmate-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (do not commit it):
   ```
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/full/path/to/tripmate-upload.jks
   ```
3. In `android/app/build.gradle.kts` replace the debug `signingConfig` in `release` with a config that reads `key.properties` (see https://docs.flutter.dev/deployment/android#configure-signing-in-gradle).
4. Build the bundle you upload to Play Console:
   ```
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`.
   For a side-loadable APK: `flutter build apk --release --split-per-abi` (smallest per-device APKs).

### iOS (App Store)

1. Open `ios/Runner.xcworkspace` in Xcode, choose your **Team** under Signing & Capabilities, keep the bundle id `com.tripmate` (change it if it is already taken on the App Store, see notes).
2. Build:
   ```
   flutter build ipa --release
   ```
3. Upload `build/ios/ipa/*.ipa` with **Transporter** or Xcode **Organizer**, then submit in App Store Connect.

---

## 4. Permissions and background location

### Android (`android/app/src/main/AndroidManifest.xml`)

| Permission | Why |
|---|---|
| `INTERNET` | Map tiles, address lookup |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Speed, position, altitude |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | Keep recording in the background (Android 14+ requires the location type) |
| `POST_NOTIFICATIONS` | Show the "TripMate is recording your trip" notification on Android 13+ |

How background recording works: when you tap Start trip, the app (while open) starts a **location foreground service** with an ongoing notification. Android lets a foreground service started from the visible app keep reading location with the normal "While using the app" permission. Because of this, TripMate does **not** ask for `ACCESS_BACKGROUND_LOCATION` ("Allow all the time"), which avoids Google Play's extra background location review.

Play Console checklist:
- **App content > Data safety:** declare *Location (precise)* collected, used for *App functionality*, stored on device, not shared.
- **Foreground service declaration:** choose *Location*, and describe "Records the route, speed and altitude of a trip the user started, until the user stops it." A short screen recording of starting a trip and the notification is usually requested.
- Provide a privacy policy URL (required because the app uses location).
- Some phone brands (Xiaomi, Oppo, Vivo, Samsung power saving) stop background apps aggressively. If recording stops when the screen is off, set TripMate's battery usage to "Unrestricted" in system settings.

### iOS (`ios/Runner/Info.plist`)

| Key | Value |
|---|---|
| `NSLocationWhenInUseUsageDescription` | Explains live trip recording |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | Explains recording when locked |
| `UIBackgroundModes` | `location` (keep recording) |
| `UISupportedInterfaceOrientations` | Portrait only (`UIRequiresFullScreen` is set so iPad accepts portrait only) |

The app uses "While Using" permission and background location updates with the blue status bar indicator, which iOS allows for a trip the user started. In Xcode, make sure **Background Modes > Location updates** is ticked under Signing & Capabilities (the Info.plist entry is already there). In App Store Connect, the **App Privacy** section should list Precise Location.

---

## 5. Changing behaviour

All values are in `lib/config.dart`:

| Setting | Default |
|---|---|
| `sampleInterval` | 3 seconds |
| `lowBatterySampleInterval` | 10 seconds |
| `lowBatteryThreshold` | 30 % |
| `lowBatteryAlertDuration` | 10 seconds |
| `idleAutoStop` | 2 hours |
| `maxTrips` | 10 |

Colours are in `lib/theme.dart` (calm teal `#1F7A80` with warm amber `#F2A65A` on a soft grey-green background).

To change the launcher icon, edit `tool/make_icons.py` (colours and shapes) and run `python3 tool/make_icons.py` from the project folder (needs `pip install pillow`). The Android 8+ adaptive icon is the vector file `android/app/src/main/res/drawable/ic_launcher_foreground.xml`.

---

## 6. Choices I made where the brief was open (please confirm)

These are guesses. Each is easy to change, so tell me if you want something different.

1. **PIN only:** there is no mobile number, OTP or account. The PIN is asked every time the app opens (and after **Lock** in the menu). Trips are stored only on this phone.
2. **Forgot PIN:** because there is no account, the only way back in is to erase the saved trips and create a new PIN. After 5 wrong tries the PIN screen waits 30 seconds before the next try.
3. **Upgrading from 1.0.0:** the old phone-number login and its PIN are not carried over. After installing this version you create a new PIN; saved trips stay.
4. **Trip names:** `Trip1`, `Trip2`, ... counting up, with the start date and time shown next to the name everywhere. You can type your own name when starting, or rename later.
5. **Prev / Next:** on the details screen, Prev trip goes to the older trip and Next trip to the newer one.
6. **Idle:** "idle" means the car has not moved more than 50 m and speed stayed under 3 km/h. When a trip auto-stops, its end time is set to the moment the car last moved, so 2 idle hours do not lower the average speed.
7. **Average speed:** distance divided by total trip time (including traffic stops).
8. **Start / stop location:** shown as an address when the phone can look one up (uses the phone's built-in geocoder, no API key), always with coordinates as well.
9. **Map:** OpenStreetMap through `flutter_map`, no API key. OSM's public tile servers are fine for light use. If the app becomes popular, switch to a tile provider with a plan (MapTiler, Stadia, Thunderforest) by changing `urlTemplate` in `lib/widgets/route_map.dart`.
10. **Units:** km/h, km and metres only. Altitude is GPS altitude above sea level and can be off by 10 to 30 m.
11. **Sampling:** TripMate saves a point every 3 seconds, or every 10 seconds when the battery is below 30% (checked every minute and whenever charging starts or stops). The GPS delivers a reading every second and TripMate keeps the ones that are due, because restarting the Android background service to change its rate is blocked by Android 12+ while the app is in the background. So below 30% the saving is in database writes and screen updates, not in the GPS itself.
12. **Graphs:** speed and altitude are drawn against time since the trip started, across the whole trip. The dashed line in the speed graph is the trip's average speed (distance divided by total time), the same number shown in the details. GPS altitude can jump by 10 to 30 m, so small bumps in the altitude graph are normal.
13. **Map credit:** the bottom corner of the map shows only "© OpenStreetMap" (the "flutter_map" prefix is gone). OpenStreetMap's tile policy requires this credit, so it stays.
14. **History limit:** only the last 10 trips are kept; older trips are deleted from the database automatically.
15. **Bundle id `com.tripmate`:** used as requested. If Apple or Google says it is already taken, a reverse-domain id you own (for example `com.yourname.tripmate`) is needed; change it in `android/app/build.gradle.kts` (`applicationId`) and in Xcode.

## 7. What was checked

- `flutter analyze`: no issues (Flutter 3.50.1, Dart 3.14).
- `flutter test`: passes (formatting, PIN storage and lockout, 3 s / 10 s sampling, graph axis and rendering).
- Not yet built on a real Android/iOS device. Do a test drive before publishing, especially background recording with the screen off.
