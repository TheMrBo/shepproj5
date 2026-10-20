# Delicious — Flutter recipe app

Native Flutter widgets recreate the pastel cooking app. Responsive navigation uses a sidebar on desktop and a bottom bar on mobile. Recipe details open as a mobile route or desktop dialog.

## Run

Requires Flutter with Dart 3.11 or later.

```sh
flutter pub get
flutter run -d chrome
```

For Android, start an emulator or connect a phone, then run `flutter run`. Use `flutter run -d windows` for Windows. The iOS project requires macOS and Xcode.

## Features

- Discover and Saved screens
- Recipe and ingredient search, category filters, and empty states
- Favorites persisted on the device using shared_preferences
- Ingredient lists and cooking steps
- Bundled reference artwork; no image service or backend required

## Source

- `lib/main.dart`: app theme, recipe model/store, and responsive Flutter screens
- `assets/recipes.json`: illustrative recipe content and ratings
- `assets/*.webp`: artwork extracted from the supplied video
- `test/widget_test.dart`: persistence, mobile navigation/search, and desktop filtering/details
- `android/`, `ios/`, `windows/`, `web/`: generated platform projects

The original HTML/CSS/JS prototype remains in the root as a design reference. Flutter's web entry point is `web/index.html`; run Flutter commands for the converted app.

## Verify and build

```sh
flutter test
dart analyze lib test --format machine
flutter build web --release --no-tree-shake-icons
```

Android/iOS platform scaffolds retain development bundle identifiers and signing defaults. Configure these before store distribution.

On this Windows checkout, the Flutter analyzer and icon subsetter fail on the accented directory name. The commands above use the working Dart analyzer and skip font subsetting. This affects build tooling, not recipe functionality.
