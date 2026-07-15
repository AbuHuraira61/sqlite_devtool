# sqlite_inspector

A Flutter DevTools extension for inspecting the **sqflite** database of a
running app: browse tables, view data, and run arbitrary SQL queries from a
DevTools tab.

## Usage

1. Add the package to the app you want to inspect:

   ```yaml
   dependencies:
     sqlite_inspector:
       path: ../db_devtoolkit/sqlite_inspector # or a pub.dev/git dependency
   ```

2. Register your database once after opening it (main isolate):

   ```dart
   import 'package:sqlite_inspector/sqlite_inspector.dart';

   final db = await openDatabase('app.db');
   SqliteInspector.register(db);
   ```

3. Run the app in **debug mode** and open Flutter DevTools (from the
   `flutter run` console link, or your IDE's "Open DevTools" action).
   DevTools detects the extension and asks you to enable it — the
   **sqlite_inspector** tab then appears alongside the built-in tabs.

## Repo layout

- `lib/sqlite_inspector.dart` — the in-app side: registers the
  `ext.sqlite_inspector.*` service extensions that the DevTools UI calls.
- `extension/devtools/` — extension config + pre-built web assets of the
  DevTools UI (built from the `db_devtoolkit` Flutter app in the parent
  directory).

## Rebuilding the DevTools UI

After changing the UI app (`db_devtoolkit`), rebuild and copy the assets:

```sh
cd db_devtoolkit
dart run devtools_extensions build_and_copy --source=. --dest=sqlite_inspector/extension/devtools
```

## Developing the UI against a live app

Run the UI in the simulated DevTools environment and paste the VM service
URI of a running debug app:

```sh
flutter run -d chrome --dart-define=use_simulated_environment=true
```
