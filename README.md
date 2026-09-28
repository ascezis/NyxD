# NyxD

NyxD is a private, offline-first diary for Android. It is designed for quick personal notes while keeping the database encrypted at rest.

## Status

> ⚠️ **Тестирование / Beta-статус**: В настоящее время ведутся активные дополнительные тесты приложения и пользовательского опыта в боевых условиях на реальных устройствах.

NyxD находится на стадии активного бета-тестирования (v0.1.0). Проект включает:
- **Шифрование данных**: стойкая изоляция ключей (Argon2id KDF + SQLCipher 256-bit AES-GCM).
- **Надёжное сохранение без потерь**: автоматический предблокировочный сброс (pre-lock flush) при сворачивании и уходе в фон.
- **Умный редактор**: визуальные чекбоксы (`☐` / `☑`) с зачёркиванием выполненных задач, нумерованные и маркированные списки с автопродолжением по Enter, заголовки и подсветка тегов.
- **Система меток**: извлечение `#тегов` из текста и быстрый выбор существующих меток в один тап.
- **Мультивыбор на главном экране**: удобное выделение нескольких заметок для пакетного удаления или закрепления.
- **Настраиваемая безопасность**: гибкий таймер блокировки (до 15 минут) с глобальным отслеживанием касаний и безопасный сброс хранилища при утере пароля.
- **Резервные копии**: зашифрованный экспорт/импорт всей базы и обмен отдельными заметками в Markdown.

Криптографический дизайн пока не проходил независимого профессионального аудита, поэтому ознакомьтесь с моделью угроз перед хранением критически важных данных.

## Скачать (Releases)

Готовые APK-файлы для установки на Android доступны в разделе **[Releases](https://github.com/ascezis/NyxD/releases)**.

## Threat model

The project aims to make casual and physical access to diary contents impractical after a lost or stolen device. It is not designed to resist state-level forensic tools or a live memory attack against a compromised, running device.

The project has not received a professional cryptographic security audit. Use it at your own risk.

See [ARCHITECTURE.md](./docs/ARCHITECTURE.md) for the technical specification and [BUILD-PLAN.md](./docs/BUILD-PLAN.md) for the implementation roadmap.

For a plain-language explanation of the security model, see [PROTECTION.md](./docs/PROTECTION.md).

For emulator setup, local development and APK build commands, see [START.md](./docs/START.md).

## Requirements

- Flutter stable
- Android SDK
- Java 17
- Android 7.0 (API 24) or newer

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
