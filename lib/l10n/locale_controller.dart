import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the application locale (language) at runtime.
///
/// - Persists the chosen language in SharedPreferences.
/// - `locale == null` means "system default".
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'thix.locale';

  static const supportedLocales = <Locale>[
    Locale('fr'),
    Locale('en'),
    Locale('sw'),
    Locale('ln'),
    Locale('ar'),
  ];

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty || raw == 'system') {
        _locale = null;
      } else {
        _locale = _parseLocale(raw);
      }
    } catch (e, st) {
      debugPrint('LocaleController.init failed: $e');
      debugPrint(st.toString());
      _locale = null;
    } finally {
      notifyListeners();
    }
  }

  Future<void> setSystem() => setLocale(null);

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.setString(_prefsKey, 'system');
      } else {
        await prefs.setString(_prefsKey, locale.languageCode);
      }
    } catch (e, st) {
      debugPrint('LocaleController.setLocale persist failed: $e');
      debugPrint(st.toString());
    }
  }

  static Locale? _parseLocale(String code) {
    for (final l in supportedLocales) {
      if (l.languageCode == code) return l;
    }
    return null;
  }
}
