# Atajos del proyecto. Cada receta es un comando de Flutter o Dart, para que
# la CI y la verificación local ejecuten exactamente lo mismo.

setup:
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter gen-l10n

run:
    flutter run

test:
    flutter test

guardianes:
    dart run tool/guardianes/todos.dart

capturas:
    flutter test tool/screenshots --update-goldens

verify: setup
    dart format --output=none --set-exit-if-changed $(git ls-files 'lib/*.dart' 'test/*.dart' 'tool/*.dart')
    flutter analyze
    flutter test
    dart run tool/guardianes/todos.dart

apk:
    flutter build apk --release --split-per-abi
    flutter build apk --release
