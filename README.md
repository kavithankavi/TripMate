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
| Landing | Login and Register buttons |
| Register | Mobile number, then a 6 digit OTP, then an optional 4 digit PIN |
| Login | Mobile number, then OTP. If a PIN is set for that number on this phone you can log in with the PIN instead ("Forgot PIN? Log in with OTP" is always available) |
| Session | Stays logged in across app restarts until you tap Log out |
| PIN | Set or change from the menu (top right). Stored only as a salted hash in the Android Keystore / iOS Keychain. 5 wrong tries removes the PIN and asks for OTP |
| Start trip | Asks for a name (default `Trip1`, `Trip2`, ... with the start date and time shown), then opens the live view |
| Live view | Speedometer dial + numeric speed, latitude, longitude, altitude, distance, max and average speed, elapsed time, and a square route map in the bottom right corner |
| Background | Keeps recording when the screen is off or you switch apps (Android foreground service with a notification, iOS background location) |
| Sampling | Location every 10 seconds. Below 30% battery it switches to every 30 seconds |
| Low battery | Below 30% an alert asks you to charge. It has an OK button and closes itself after 10 seconds |
| Stop trip | From the Home screen or the live view. Stops automatically after 2 hours without movement |
| History | Your last 10 trips. Tap one for details, then use Prev trip / Next trip |
| Trip details | Start location, stop location, distance covered, average speed, max speed, max altitude, plus duration and a route map. Rename with the pencil icon |
| Storage | Local SQLite database inside the app (`tripmate.db`) |

---

## Project layout

```
lib/
  main.dart                  App start
  app.dart                   MaterialApp, low battery alert and auto-stop notice
  config.dart                All tunable values (intervals, thresholds, OTP mode)
  theme.dart                 Colour palette and theme
  firebase_options.dart      Placeholder, replaced by `flutterfire configure`
  models/trip.dart           Trip and TrackPoint
  data/trip_database.dart    SQLite (sqflite)
  services/
    auth_service.dart        OTP interface, mock (demo) and Firebase versions
    session_store.dart       Session + hashed PIN in secure storage
    trip_tracker.dart        Location sampling, battery rules, idle auto-stop
    services.dart            Creates the services at start-up
  screens/                   Landing, phone, OTP, PIN, home, live trip, history, details
  widgets/                   Speedometer (CustomPainter), route map, logo, timed alert
tool/make_icons.py           Regenerates the launcher icon PNGs
```

No images are bundled. The logo, speedometer and icons are drawn in code or as small vector files. Map tiles are downloaded only while a map is on screen.

Packages used (kept to a minimum): `geolocator`, `battery_plus`, `sqflite`, `path`, `flutter_map`, `latlong2`, `geocoding`, `flutter_secure_storage`, `crypto`, `intl`, `firebase_core`, `firebase_auth`.

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
4. Press **F5** and choose **TripMate (demo OTP 123456)**.

The default build runs in **demo mode**: no SMS is sent and the OTP is always `123456`. This lets you try the whole app without any backend. The landing screen says "Demo mode" so you never confuse it with a real build.

> Tip: location is easiest to test on a real phone in a car. On the Android emulator use **Extended controls > Location > Routes** to play back a route. On the iOS Simulator use **Features > Location > Freeway Drive**.

Command line equivalents:
```
flutter run                                   # demo OTP
flutter run --dart-define=AUTH_MODE=firebase  # real OTP (after step 3)
flutter test                                  # unit tests
flutter analyze                               # lints
```

## 3. Switching to real OTP with Firebase

Real SMS OTP uses **Firebase Phone Authentication** (free tier includes a number of SMS per day; check current Firebase pricing for your country).

1. Create a project at https://console.firebase.google.com.
2. **Build > Authentication > Get started > Sign-in method > Phone > Enable.**
3. Install the tools and link the app (this overwrites `lib/firebase_options.dart`):
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<your-firebase-project-id> --platforms=android,ios --android-package-name=com.tripmate --ios-bundle-id=com.tripmate
   ```
4. **Android:** add your SHA-1 and SHA-256 fingerprints in Firebase (**Project settings > Your apps > Android app**). Get the debug ones with:
   ```
   cd android && ./gradlew signingReport
   ```
   Add your release (upload) key fingerprints too, and the Play App Signing key from Play Console once you publish. Also enable the **Play Integrity API** for the Google Cloud project.
5. **iOS:**
   - In Xcode open `ios/Runner.xcworkspace`, select **Runner > Signing & Capabilities**, add **Push Notifications** and **Background Modes > Remote notifications** (already declared in Info.plist).
   - Upload an **APNs authentication key** in Firebase (**Project settings > Cloud Messaging > Apple app configuration**).
   - Add the reCAPTCHA fallback URL scheme: in **Runner > Info > URL Types** add one with the `REVERSED_CLIENT_ID` from `ios/Runner/GoogleService-Info.plist` (or the Encoded App ID shown in Firebase).
6. Run with `flutter run --dart-define=AUTH_MODE=firebase`, or the **TripMate (Firebase OTP)** entry in VS Code.
7. For testing without SMS, add test numbers in **Authentication > Sign-in method > Phone > Phone numbers for testing**.

If you would rather use a different SMS provider (MSG91, Twilio, your own server), implement the `AuthService` interface in `lib/services/auth_service.dart`. Nothing else needs to change.

## 4. Build for release

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
   flutter build appbundle --release --dart-define=AUTH_MODE=firebase
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`.
   For a side-loadable APK: `flutter build apk --release --split-per-abi --dart-define=AUTH_MODE=firebase` (smallest per-device APKs).

### iOS (App Store)

1. Open `ios/Runner.xcworkspace` in Xcode, choose your **Team** under Signing & Capabilities, keep the bundle id `com.tripmate` (change it if it is already taken on the App Store, see notes).
2. Build:
   ```
   flutter build ipa --release --dart-define=AUTH_MODE=firebase
   ```
3. Upload `build/ios/ipa/*.ipa` with **Transporter** or Xcode **Organizer**, then submit in App Store Connect.

> Always ship store builds with `AUTH_MODE=firebase`. The demo mode accepts `123456` for any number.

---

## 5. Permissions and background location

### Android (`android/app/src/main/AndroidManifest.xml`)

| Permission | Why |
|---|---|
| `INTERNET` | Map tiles, OTP, address lookup |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Speed, position, altitude |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` | Keep recording in the background (Android 14+ requires the location type) |
| `POST_NOTIFICATIONS` | Show the "TripMate is recording your trip" notification on Android 13+ |

How background recording works: when you tap Start trip, the app (while open) starts a **location foreground service** with an ongoing notification. Android lets a foreground service started from the visible app keep reading location with the normal "While using the app" permission. Because of this, TripMate does **not** ask for `ACCESS_BACKGROUND_LOCATION` ("Allow all the time"), which avoids Google Play's extra background location review.

Play Console checklist:
- **App content > Data safety:** declare *Location (precise)* collected, used for *App functionality*, stored on device, not shared. Declare *Phone number* collected for *Account management* (Firebase).
- **Foreground service declaration:** choose *Location*, and describe "Records the route, speed and altitude of a trip the user started, until the user stops it." A short screen recording of starting a trip and the notification is usually requested.
- Provide a privacy policy URL (required because the app uses location and phone number).
- Some phone brands (Xiaomi, Oppo, Vivo, Samsung power saving) stop background apps aggressively. If recording stops when the screen is off, set TripMate's battery usage to "Unrestricted" in system settings.

### iOS (`ios/Runner/Info.plist`)

| Key | Value |
|---|---|
| `NSLocationWhenInUseUsageDescription` | Explains live trip recording |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | Explains recording when locked |
| `UIBackgroundModes` | `location` (keep recording), `remote-notification` (Firebase phone auth) |

The app uses "While Using" permission and background location updates with the blue status bar indicator, which iOS allows for a trip the user started. In Xcode, make sure **Background Modes > Location updates** is ticked under Signing & Capabilities (the Info.plist entry is already there). In App Store Connect, the **App Privacy** section should list Precise Location and Phone Number as above.

---

## 6. Changing behaviour

All values are in `lib/config.dart`:

| Setting | Default |
|---|---|
| `sampleInterval` | 10 seconds |
| `lowBatterySampleInterval` | 30 seconds |
| `lowBatteryThreshold` | 30 % |
| `lowBatteryAlertDuration` | 10 seconds |
| `idleAutoStop` | 2 hours |
| `maxTrips` | 10 |
| `defaultCountryCode` | +91 |

Colours are in `lib/theme.dart` (calm teal `#1F7A80` with warm amber `#F2A65A` on a soft grey-green background).

To change the launcher icon, edit `tool/make_icons.py` (colours and shapes) and run `python3 tool/make_icons.py` from the project folder (needs `pip install pillow`). The Android 8+ adaptive icon is the vector file `android/app/src/main/res/drawable/ic_launcher_foreground.xml`.

---

## 7. Choices I made where the brief was open (please confirm)

These are guesses. Each is easy to change, so tell me if you want something different.

1. **OTP provider:** Firebase Phone Auth, with a demo mode (code `123456`) as the default build so the app runs without a backend.
2. **What the PIN is for:** a quick login on this phone instead of waiting for an OTP (after you log out). It is optional after registration ("Skip for now"). Alternative: use the PIN as an app lock every time the app opens.
3. **Register vs Login:** both verify the number by OTP. Without a server there is no central list of registered numbers, so Login does not reject a number that was never registered; Register additionally offers PIN setup. A real "is this number registered" check needs a small backend (for example Firestore).
4. **Trip names:** `Trip1`, `Trip2`, ... counting up, with the start date and time shown next to the name everywhere. You can type your own name when starting, or rename later.
5. **Prev / Next:** on the details screen, Prev trip goes to the older trip and Next trip to the newer one.
6. **Idle:** "idle" means the car has not moved more than 50 m and speed stayed under 3 km/h. When a trip auto-stops, its end time is set to the moment the car last moved, so 2 idle hours do not lower the average speed.
7. **Average speed:** distance divided by total trip time (including traffic stops).
8. **Start / stop location:** shown as an address when the phone can look one up (uses the phone's built-in geocoder, no API key), always with coordinates as well.
9. **Map:** OpenStreetMap through `flutter_map`, no API key. OSM's public tile servers are fine for light use. If the app becomes popular, switch to a tile provider with a plan (MapTiler, Stadia, Thunderforest) by changing `urlTemplate` in `lib/widgets/route_map.dart`.
10. **Default country code:** +91. Editable on the phone number screen.
11. **Units:** km/h, km and metres only. Altitude is GPS altitude above sea level and can be off by 10 to 30 m.
12. **Low battery sampling:** below 30% TripMate saves a point every 30 seconds. On Android the GPS itself keeps its 10 second rate, because restarting the background service while the app is in the background is blocked by Android 12+. Only every third reading is used.
13. **History limit:** only the last 10 trips are kept; older trips are deleted from the database automatically.
14. **Bundle id `com.tripmate`:** used as requested. If Apple or Google says it is already taken, a reverse-domain id you own (for example `com.yourname.tripmate`) is needed; change it in `android/app/build.gradle.kts` (`applicationId`) and in Xcode.

## 8. What was checked

- `flutter analyze`: no issues (Flutter 3.50.1, Dart 3.14).
- `flutter test`: passes.
- Not yet built on a real Android/iOS device. Do a test drive before publishing, especially background recording with the screen off.
