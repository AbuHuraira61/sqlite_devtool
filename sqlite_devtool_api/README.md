# sqlite_devtool_api

A Flutter DevTools extension for inspecting the **sqflite** database of a
running app: browse tables, view data, and run arbitrary SQL queries from a
DevTools tab.

## Usage

1. Add the package to the app you want to inspect:

   ```yaml
   dependencies:
     sqlite_devtool_api:
       path: ../sqlite_devtool/sqlite_devtool_api # or a pub.dev/git dependency
   ```

2. Register your database once after opening it (main isolate):

   ```dart
   import 'package:sqlite_devtool_api/sqlite_devtool_api.dart';

   final db = await openDatabase('app.db');
   SqliteInspector.register(db);
   ```

3. Run the app in **debug mode** and open Flutter DevTools (from the
   `flutter run` console link, or your IDE's "Open DevTools" action).
   DevTools detects the extension and asks you to enable it — the
   **sqlite_devtool_api** tab then appears alongside the built-in tabs.

## Repo layout

- `lib/sqlite_devtool_api.dart` — the in-app side: registers the
  `ext.sqlite_devtool_api.*` service extensions that the DevTools UI calls.
- `extension/devtools/` — extension config + pre-built web assets of the
  DevTools UI (built from the `sqlite_devtool` Flutter app in the parent
  directory).

## Rebuilding the DevTools UI

After changing the UI app (`sqlite_devtool`), rebuild and copy the assets:

```sh
cd sqlite_devtool
dart run devtools_extensions build_and_copy --source=. --dest=sqlite_devtool_api/extension/devtools
```

## Developing the UI against a live app

Run the UI in the simulated DevTools environment and paste the VM service
URI of a running debug app:

```sh
flutter run -d chrome --dart-define=use_simulated_environment=true
```

`
