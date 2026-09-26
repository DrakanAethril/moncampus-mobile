# moncampus-mobile

Mobile app (Flutter) for [moncampus](https://github.com/DrakanAethril/moncampus), consuming its API Platform backend.

## Running against a local moncampus

The dev backend (`docker compose up --wait` in the moncampus repository) answers on **plain HTTP**,
port 80 - `https://localhost` is not served in dev at all. With no `API_BASE_URL`, the app picks the
address that reaches it (`lib/services/api_config.dart`):

| Target | Command | API it calls |
|---|---|---|
| Chrome | `flutter run -d chrome` | `http://localhost` (CORS is open to any localhost port) |
| macOS | `flutter run -d macos` | `http://localhost` |
| Android emulator | `flutter emulators --launch Pixel_6_API_UpsideDownCake` then `flutter run` | `http://10.0.2.2` (the emulator's name for the Mac) |
| A real phone on the same Wi-Fi | `flutter run --dart-define=API_BASE_URL=http://<the Mac's IP>` | the Mac's LAN address - `ipconfig getifaddr en0` gives it |

A real Android phone only reaches a LAN address over plain HTTP in a **debug** build:
`android/app/src/debug/res/xml/network_security_config.xml` allows it there, and release builds keep
the strict policy. Dev accounts: `admin` / `password` (fictitious LDAP seed).

## License

Copyright (c) 2026 Sébastien Tharaud. Released under the **MIT License** — see [LICENSE](LICENSE).

The licence differs from the MonCampus server, which is AGPL-3.0-or-later: this repository is a thin
client distributed through app stores, and Apple's App Store terms are widely held to be incompatible
with the GPL family. It should stay permissively licensed.

Institution Beaupeyrat's names, logos and emblems are not covered by the licence, and the bundled fonts
carry their own SIL Open Font License — see [NOTICE](NOTICE).
