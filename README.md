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
- Cook with what I have: saved pantry ingredients, ranked recipe matches,
  missing ingredients, and an all-ingredients-available filter on Discover.
  Matching uses ingredient names, common plurals, and preparation words;
  quantities and substitutions are not inferred.
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

## Import cooking links

Select **Import recipe** beside Explore recipes, paste a full HTTP(S) recipe-page URL
(or use **Paste link** with the device clipboard), and select
**Import recipe**. Review the extracted ingredients and steps, then select
**Save recipe**. Imported recipes persist locally, appear in Discover under the
Imported filter, and can be favorited to appear in Saved recipes. Importing the
same URL again refreshes the existing recipe instead of creating a duplicate.
The original source URL is retained in the recipe details.

The importer reads Schema.org Recipe JSON-LD, including graph objects and grouped
HowToStep instructions. It requires a title, ingredients, and instructions.
Dish images are imported from recipe data or page image metadata. Step photos
come from explicit step images or matching illustrated cooking instructions;
unmatched steps display a placeholder. Some sites provide shared photo collages.
Cooking mode shows one step per page with Previous, Next step, and Done controls.
Full instructions are preferred over duplicate abbreviated sections; promotional
descriptions are omitted and recipe notices are shown separately.
Missing time is shown as “Time not listed”; imports do not invent ratings.
Requests time out after 20 seconds and are limited to
5 MiB. Tests use deterministic HTTP fixtures and do not depend on external sites.

Native apps fetch pages directly. Flutter web imports only work when the source
website permits cross-origin requests (CORS); most recipe sites do not. There is
no hosted proxy in this project. Login-protected, anti-bot, JavaScript-only,
video-only, social media, and pages without Recipe JSON-LD are not supported.
HTTP links may also be restricted by platform transport policies; prefer HTTPS.
