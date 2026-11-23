import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opacity helper that works on every Flutter version.
Color alpha(Color c, double opacity) => c.withAlpha((opacity * 255).round().clamp(0, 255));

/// One colour combination from the "Premium Website Colour Combos" guide.
/// bg = 60% background, text = 30% text, accent = 10% accent,
/// card/line = the small 5% support colours.
class AppPalette {
  final String id;
  final String name;
  final String feel;
  final Color bg;
  final Color text;
  final Color accent;
  final Color card;
  final Color line;
  final Color button;
  final Color onButton;
  final bool dark;

  const AppPalette({
    required this.id,
    required this.name,
    required this.feel,
    required this.bg,
    required this.text,
    required this.accent,
    required this.card,
    required this.line,
    required this.button,
    required this.onButton,
    required this.dark,
  });

  /// Softer secondary text colour.
  Color get muted => Color.alphaBlend(alpha(text, 0.62), bg);

  /// Accent colour that is safe to use for small text (falls back to text colour).
  Color get accentText => _contrast(accent, bg) >= 3 ? accent : text;

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}

const List<AppPalette> kPalettes = [
  AppPalette(
    id: 'dark_tech', name: 'Dark Tech & Violet', feel: 'Futuristic',
    bg: Color(0xFF0A0A12), text: Color(0xFFE6E6F0), accent: Color(0xFF7457FF),
    card: Color(0xFF1A1A2E), line: Color(0xFF2A2A48),
    button: Color(0xFF7457FF), onButton: Color(0xFFFFFFFF), dark: true,
  ),
  AppPalette(
    id: 'midnight_gold', name: 'Midnight Gold', feel: 'Luxurious',
    bg: Color(0xFF0B0B0F), text: Color(0xFFF5F1E8), accent: Color(0xFFC9A24A),
    card: Color(0xFF15151B), line: Color(0xFF2A2A33),
    button: Color(0xFFC9A24A), onButton: Color(0xFF111111), dark: true,
  ),
  AppPalette(
    id: 'navy_champagne', name: 'Navy & Champagne', feel: 'Trustworthy',
    bg: Color(0xFFF7F5F0), text: Color(0xFF0E1A2B), accent: Color(0xFFB8955E),
    card: Color(0xFFFFFFFF), line: Color(0xFFE4DED2),
    button: Color(0xFFB8955E), onButton: Color(0xFF111111), dark: false,
  ),
  AppPalette(
    id: 'emerald_brass', name: 'Emerald & Brass', feel: 'Heritage',
    bg: Color(0xFF0F3D2E), text: Color(0xFFF3EEE3), accent: Color(0xFFC9A46A),
    card: Color(0xFF1C5A45), line: Color(0xFF2B6E57),
    button: Color(0xFFC9A46A), onButton: Color(0xFF111111), dark: true,
  ),
  AppPalette(
    id: 'slate_terracotta', name: 'Slate & Terracotta', feel: 'Modern',
    bg: Color(0xFFF2EFEA), text: Color(0xFF2E3440), accent: Color(0xFFB9572F),
    card: Color(0xFFFAF8F5), line: Color(0xFFDAD5CD),
    button: Color(0xFFB9572F), onButton: Color(0xFFFFFFFF), dark: false,
  ),
  AppPalette(
    id: 'sage_sand', name: 'Sage & Sand', feel: 'Calm',
    bg: Color(0xFFF4F1EA), text: Color(0xFF2F3A2F), accent: Color(0xFF5E7A5B),
    card: Color(0xFFECE5D6), line: Color(0xFFD9CBB3),
    button: Color(0xFF5E7A5B), onButton: Color(0xFFFFFFFF), dark: false,
  ),
  AppPalette(
    id: 'blush_charcoal', name: 'Blush & Charcoal', feel: 'Soft',
    bg: Color(0xFFFBF5F2), text: Color(0xFF2B2B2E), accent: Color(0xFFD8A7A0),
    card: Color(0xFFFFFFFF), line: Color(0xFFEADBD5),
    button: Color(0xFF2B2B2E), onButton: Color(0xFFFFFFFF), dark: false,
  ),
  AppPalette(
    id: 'ivory_espresso', name: 'Ivory & Espresso', feel: 'Warm',
    bg: Color(0xFFFAF7F2), text: Color(0xFF3B2A20), accent: Color(0xFF9C7650),
    card: Color(0xFFFFFFFF), line: Color(0xFFE9E1D6),
    button: Color(0xFF9C7650), onButton: Color(0xFF111111), dark: false,
  ),
  AppPalette(
    id: 'burgundy_cream', name: 'Burgundy & Cream', feel: 'Bold',
    bg: Color(0xFFF6F0E6), text: Color(0xFF5A1E2B), accent: Color(0xFFA8823F),
    card: Color(0xFFFBF7F0), line: Color(0xFFE3D8C3),
    button: Color(0xFFA8823F), onButton: Color(0xFF111111), dark: false,
  ),
  AppPalette(
    id: 'mono_noir', name: 'Monochrome Noir', feel: 'Minimal',
    bg: Color(0xFFFFFFFF), text: Color(0xFF111111), accent: Color(0xFF111111),
    card: Color(0xFFF6F6F6), line: Color(0xFFE5E5E5),
    button: Color(0xFF111111), onButton: Color(0xFFFFFFFF), dark: false,
  ),
];

/// Holds the chosen palette and remembers it between app launches.
class ThemeController extends ChangeNotifier {
  AppPalette palette = kPalettes.first;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('palette');
      if (id != null) {
        final found = kPalettes.where((p) => p.id == id);
        if (found.isNotEmpty) {
          palette = found.first;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> select(AppPalette p) async {
    palette = p;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('palette', p.id);
    } catch (_) {}
  }
}

/// Use `context.pal` inside build methods to read the current colours.
extension PaletteContext on BuildContext {
  AppPalette get pal => Provider.of<ThemeController>(this).palette;
}

ThemeData buildTheme(AppPalette p) {
  final base = ThemeData(brightness: p.dark ? Brightness.dark : Brightness.light, useMaterial3: true);
  final scheme = ColorScheme.fromSeed(seedColor: p.accent, brightness: base.brightness).copyWith(
    primary: p.button,
    onPrimary: p.onButton,
    secondary: p.accent,
    surface: p.card,
    onSurface: p.text,
    outline: p.line,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      border: border(p.line),
      enabledBorder: border(p.line),
      focusedBorder: border(p.accent, 2),
      hintStyle: TextStyle(color: p.muted),
      labelStyle: TextStyle(color: p.muted),
      prefixIconColor: p.muted,
      suffixIconColor: p.muted,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.text,
      contentTextStyle: TextStyle(color: p.bg),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
