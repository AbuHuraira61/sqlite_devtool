import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/inspector_shell.dart';
import 'src/theme.dart';

void main() {
  runApp(const SqliteInspectorApp());
}

/// SQLite Inspector — a DevTools extension for browsing, mapping, and
/// querying the sqflite database of the connected app.
class SqliteInspectorApp extends StatelessWidget {
  const SqliteInspectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DevToolsExtension(
      child: MaterialApp(
        title: 'SQLite Inspector',
        debugShowCheckedModeBanner: false,
        theme: buildInspectorTheme(),
        home: const InspectorShell(),
      ),
    );
  }
}
