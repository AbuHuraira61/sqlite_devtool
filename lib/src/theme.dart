import 'package:flutter/material.dart';

/// Blueprint palette: the inspector reads like a drafting table — deep ink
/// canvas, spec-sheet cards, drafting-blue relationship lines, brass keys.
abstract final class Palette {
  static const canvas = Color(0xFF0D1220);
  static const paper = Color(0xFF161D2E);
  static const paperRaised = Color(0xFF1C2438);
  static const line = Color(0xFF26304A);
  static const grid = Color(0xFF19213A);
  static const blueprint = Color(0xFF6C9BFF);
  static const brass = Color(0xFFFFC66D);
  static const mint = Color(0xFF63E2B7);
  static const rose = Color(0xFFF87683);
  static const textHi = Color(0xFFE8EDF7);
  static const textMid = Color(0xFF8E9AB3);
  static const textLow = Color(0xFF55617A);
}

const monoFamily = 'monospace';

ThemeData buildInspectorTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: Palette.blueprint,
      secondary: Palette.brass,
      surface: Palette.paper,
      error: Palette.rose,
    ),
    dividerColor: Palette.line,
    splashFactory: InkRipple.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Palette.blueprint,
      selectionColor: Color(0x336C9BFF),
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Palette.line),
      radius: Radius.circular(4),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Palette.paperRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Palette.line),
      ),
      textStyle: const TextStyle(color: Palette.textHi, fontSize: 11),
    ),
  );
}

/// Uppercase tracked label used for panel headers.
class PanelLabel extends StatelessWidget {
  const PanelLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Palette.textLow,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}
