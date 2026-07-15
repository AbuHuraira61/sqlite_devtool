# db_devtoolkit — SQLite Inspector for Flutter DevTools

A DevTools extension that lets you inspect the sqflite database of a running
Flutter app: browse tables, run SQL queries, and see an interactive **schema
map** of how tables connect to each other via foreign keys.

This repo contains two parts:

- **The extension UI** (`lib/`) — the panel shown inside DevTools.
- **[`sqlite_inspector/`](sqlite_inspector/)** — the package your apps depend
  on. It registers the service extensions that read the database, and carries
  the built UI so DevTools can discover it.

## Use it in an app

```yaml
dependencies:
  sqlite_inspector:
    path: ../db_devtoolkit/sqlite_inspector
```

```dart
import 'package:sqlite_inspector/sqlite_inspector.dart';

final db = await openDatabase('app.db');
SqliteInspector.register(db);
```

Run the app in debug mode, open Flutter DevTools, enable the extension when
prompted — the **sqlite_devtool** tab appears.

## Change something

Read **[DEVELOPMENT.md](DEVELOPMENT.md)** — it has a recipe for every kind of
change (UI, database handlers, new features, icon/name) and the rebuild rules
that make changes actually show up.
w up.
