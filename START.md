# NyxD — запуск проекта

## Быстрый запуск

Открой PowerShell в корне проекта:

```powershell
cd C:\Users\azis\Desktop\NyxD
```

Запусти Android-эмулятор:

```powershell
flutter emulators --launch Pixel_7
```

Дождись полной загрузки Android и появления главного экрана телефона. Затем проверь, что Flutter видит эмулятор:

```powershell
flutter devices
```

В списке должно появиться Android-устройство примерно такого вида:

```text
emulator-5554 • android-x64 • Android
```

Запусти NyxD на эмуляторе:

```powershell
flutter run -d emulator-5554
```

Терминал необходимо оставить открытым на всё время отладки.

## Управление запущенным приложением

Когда команда `flutter run` активна:

- `r` — hot reload: применить изменения без полного перезапуска приложения;
- `R` — hot restart: перезапустить Dart-приложение;
- `q` — остановить приложение и завершить отладку;
- `h` — показать все доступные команды Flutter.

Обычно после изменения Dart-файла достаточно сохранить его и нажать `r` в терминале.

## Запуск эмулятора через Android Studio

Если команда запуска эмулятора не сработала:

1. Открой Android Studio.
2. Перейди в **Tools → Device Manager**.
3. Найди устройство **Pixel 7**.
4. Нажми кнопку ▶ рядом с ним.
5. Дождись полной загрузки Android.
6. Вернись в терминал и выполни:

```powershell
flutter run -d emulator-5554
```

## Если эмулятор имеет статус `offline`

Перезапусти Android Debug Bridge:

```powershell
adb kill-server
adb start-server
flutter devices --device-timeout 30
```

Если устройство появилось в списке, снова запусти приложение:

```powershell
flutter run -d emulator-5554
```

Если это не помогло, закрой эмулятор и в Android Studio выбери **Device Manager → Pixel 7 → Cold Boot**.

## Если команда `flutter` не найдена

Добавь Flutter в `PATH` текущего окна PowerShell:

```powershell
$env:Path = "C:\Users\azis\development\flutter\bin;$env:Path"
```

Проверь установку:

```powershell
flutter --version
```

После этого повтори команды из раздела «Быстрый запуск».

## Проверки перед сборкой

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

## Сборка APK

Debug-сборка:

```powershell
flutter build apk --debug
```

Готовый файл появится здесь:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

Debug APK нужен для отдельной установки. Для обычной разработки удобнее использовать `flutter run` и hot reload.
