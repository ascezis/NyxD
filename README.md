# NyxD

NyxD is a private, offline-first diary for Android. It is designed for quick personal notes while keeping the database encrypted at rest.

## Status

NyxD has reached a tested Android MVP. It includes encrypted local storage,
notes, tags, search, trash, automatic locking, encrypted backups and Markdown
import/export. The cryptographic design has not yet received an independent
professional audit, so review the threat model before relying on it for
sensitive data.

## Threat model

The project aims to make casual and physical access to diary contents impractical after a lost or stolen device. It is not designed to resist state-level forensic tools or a live memory attack against a compromised, running device.

The project has not received a professional cryptographic security audit. Use it at your own risk.

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the technical specification and [BUILD-PLAN.md](./BUILD-PLAN.md) for the implementation roadmap.

For a plain-language explanation of the security model, see [PROTECTION.md](./PROTECTION.md).

For emulator setup, local development and APK build commands, see [START.md](./START.md).

## Requirements

- Flutter stable
- Android SDK
- Java 17
- Android 6.0 (API 23) or newer

## Development

```shell
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
```

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Project structure

```text
lib/
├── app/                  Application shell and global theme
├── core/                 Shared infrastructure and security primitives
└── features/             Feature-oriented application code
```

The `REFERENCES` directory contains the authoritative visual references for the UI. It is design input, not an application asset directory.

## Security reports

Please follow the private reporting process in [SECURITY.md](./SECURITY.md).

## License

NyxD is licensed under the [MIT License](./LICENSE).
