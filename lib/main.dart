import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'src/inspector_shell.dart';
import 'src/theme.dart';

void main() {
  runApp(const SqliteDevtoolApp());
}

/// SQLite DevTool — a DevTools extension for browsing, mapping, and
/// querying the sqflite database of the connected app.
class SqliteDevtoolApp extends StatelessWidget {
  const SqliteDevtoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DevToolsExtension(
      child: MaterialApp(
        title: 'SQLite DevTool',
        debugShowCheckedModeBanner: false,
        theme: buildInspectorTheme(),
        home: const InspectorShell(),
      ),
    );
  }
}
