# Development Guide — SQLite Inspector

This guide answers one question: **"If I have to change something, what do I do?"**

## How the pieces fit together

There are three parts. Knowing which part you are changing tells you which
steps to follow.

```
┌────────────────────────────┐     service extension calls      ┌─────────────────────────────┐
│  db_devtoolkit (this repo) │  ext.sqlite_inspector.getSchema  │  Your app (debug mode)      │
│  The DevTools UI           │ ───────────────────────────────► │  + sqlite_inspector package │
│  runs inside DevTools      │ ◄─────────────────────────────── │  reads/writes the sqflite   │
└────────────────────────────┘         JSON responses           │  database                   │
                                                                └─────────────────────────────┘
```

1. **The UI app** (`lib/` in this repo) — the panel you see inside DevTools.
2. **The package** (`sqlite_inspector/`) — lives inside your app. Registers the
   `ext.sqlite_inspector.*` handlers that actually touch the database.
3. **The built assets** (`sqlite_inspector/extension/devtools/build/`) —
   DevTools does NOT run your `lib/` source. It loads this pre-built copy.

## The two golden rules

**Rule 1 — Changed anything in `lib/` (the UI)?**
The change is invisible until you rebuild the assets:

```powershell
dart run devtools_extensions build_and_copy --source=. --dest=sqlite_inspector/extension/devtools
```

Then close and reopen the DevTools tab.

**Rule 2 — Changed anything in `sqlite_devtool_api/lib/` (the app side)?**
No rebuild needed, but the code runs inside your app — so **stop your app and
run it again** (a full restart, not hot reload). Then press Refresh in the
extension.

## "I want to change…" — recipes

### …colors, fonts, spacing

Everything lives in [lib/src/theme.dart](lib/src/theme.dart). The `Palette`
class holds every color in the extension — change a hex value there and it
updates everywhere. Then apply **Rule 1**.

### …the sidebar, top bar, or console

[lib/src/inspector_shell.dart](lib/src/inspector_shell.dart) — the outer frame:
table list, search box, Data/Schema map switcher, collapsible log console.
Then **Rule 1**.

### …the SQL console or results grid

[lib/src/views/data_view.dart](lib/src/views/data_view.dart) — query input,
results table, row cap (`_maxRowsShown`), status bar, empty/error states.
Then **Rule 1**.

### …the schema map (cards, lines, layout)

[lib/src/views/schema_map_view.dart](lib/src/views/schema_map_view.dart):

- Card size and rows shown: the `_cardWidth`, `_rowHeight`, `_maxColumnRows`
  constants at the top.
- How relationships are inferred from `user_id`-style names: `_buildEdges()`.
- Auto-arrange layout: `_gridPositions()`.
- How lines/arrows/dot-grid are drawn: `_BlueprintPainter`.

Then **Rule 1**.

### …how queries run against the database

[sqlite_inspector/lib/sqlite_inspector.dart](sqlite_inspector/lib/sqlite_inspector.dart)
— the `executeQuery` handler (read vs. write detection, BLOB handling) and the
`getSchema` handler (tables, columns, foreign keys, row counts).
Then **Rule 2**.

### …add a brand-new feature (needs both sides)

Example: a "list indexes" feature.

1. **Package side** — register a new handler in
   `sqlite_inspector/lib/sqlite_inspector.dart` inside `register()`:

   ```dart
   developer.registerExtension('ext.sqlite_inspector.getIndexes',
       (method, params) async {
     try {
       final db = _requireDb();
       final rows = await db.rawQuery(
           "SELECT name, tbl_name FROM sqlite_master WHERE type = 'index'");
       return _ok({'indexes': rows});
     } catch (e) {
       return _error(e);
     }
   });
   ```

   Keep the response shape: `_ok()` wraps your payload so the UI can decode
   `response.json['result']` as a JSON string.

2. **UI side** — add a method to
   [lib/src/inspector_service.dart](lib/src/inspector_service.dart) that calls
   `_call('ext.sqlite_inspector.getIndexes')`, a model in
   [lib/src/models.dart](lib/src/models.dart) if the data is structured, and
   the widgets that show it.

3. Apply **Rule 2** (restart your app) and **Rule 1** (rebuild assets).

### …the extension's name, icon, or version

[sqlite_inspector/extension/devtools/config.yaml](sqlite_inspector/extension/devtools/config.yaml):

- `name` must exactly match the package name in
  `sqlite_inspector/pubspec.yaml` — DevTools refuses the extension otherwise.
- `materialIconCodePoint` sets the tab icon (any Material icon code point).
- When you release a change, bump `version` in **both** `config.yaml` and
  `sqlite_inspector/pubspec.yaml` so they stay in sync.

### …use it in another app

Add the package to that app and register the database:

```yaml
dependencies:
  sqlite_inspector:
    path: C:/Users/Development/Desktop/db_devtoolkit/sqlite_inspector
```

```dart
final db = await openDatabase('app.db');
SqliteInspector.register(db);
```

To share it beyond your machine, publish `sqlite_inspector` to a git repo or
pub.dev (remove `publish_to: 'none'` from its pubspec first).

## Checking a change before you ship it

Run these from the repo root, in order:

| Step | Command | Catches |
|---|---|---|
| 1. Analyze UI | `flutter analyze` | compile errors, lint issues |
| 2. Analyze package | `cd sqlite_inspector; flutter analyze; cd ..` | same, for the app side |
| 3. Tests | `flutter test` | schema-parsing regressions |
| 4. Live preview | `flutter run -d chrome --dart-define=use_simulated_environment=true` | see the real UI without rebuilding |
| 5. Rebuild assets | `dart run devtools_extensions build_and_copy --source=. --dest=sqlite_inspector/extension/devtools` | ships the UI change |
| 6. Validate | `dart run devtools_extensions validate --package=sqlite_inspector` | broken extension structure |

Step 4 is the fast development loop: it runs the extension in a fake DevTools
frame in Chrome with hot reload. Paste the VM service URI of a running debug
app (printed by `flutter run`) into its connect field and you can test against
real data without rebuilding anything.

Note on tests: `flutter test` runs on the Dart VM, and anything that imports
`devtools_extensions` is web-only — so tests can only import pure-Dart files
like `lib/src/models.dart`. Widget tests would need
`flutter test --platform chrome`.

## Troubleshooting

| Symptom | Cause & fix |
|---|---|
| My UI change doesn't show in DevTools | You skipped **Rule 1** (rebuild), or DevTools is serving the old copy — rebuild, then close the DevTools browser tab and open it again. |
| "No tables found" | The app isn't running in debug mode, or `SqliteInspector.register(db)` was never called, or the database failed to open. Check the app's own logs. |
| Schema map is empty but tables load | The app is still running the old package without `getSchema` — full restart of the app (**Rule 2**). |
| Everything fails on Windows desktop | Plain `sqflite` has no Windows support. The app must use `sqflite_common_ffi` (`sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;`). |
| Extension tab doesn't appear at all | The app being debugged doesn't depend on `sqlite_inspector`, or `config.yaml` `name` doesn't match the package name — run the validate command. |

## File map

| Path | What it is | Rule |
|---|---|---|
| `lib/main.dart` | App entry, wraps everything in `DevToolsExtension` | 1 |
| `lib/src/theme.dart` | `Palette` colors + theme | 1 |
| `lib/src/models.dart` | Schema data classes + JSON parsing | 1 |
| `lib/src/inspector_service.dart` | Calls the `ext.sqlite_inspector.*` extensions | 1 |
| `lib/src/inspector_shell.dart` | Sidebar, top bar, console, view switching | 1 |
| `lib/src/views/data_view.dart` | SQL console + results grid | 1 |
| `lib/src/views/schema_map_view.dart` | Interactive schema map | 1 |
| `sqlite_inspector/lib/sqlite_inspector.dart` | In-app handlers (the database side) | 2 |
| `sqlite_inspector/extension/devtools/config.yaml` | Extension manifest | reopen DevTools |
| `sqlite_inspector/extension/devtools/build/` | Built UI assets — **never edit by hand**, always regenerate | — |
| `test/widget_test.dart` | Schema parsing tests | — |

�� |
