import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Language data class
class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final Locale locale;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.locale,
  });
}

// Available languages
const List<AppLanguage> availableLanguages = [
  AppLanguage(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    locale: Locale('en', 'US'),
  ),
  AppLanguage(
    code: 'ar',
    name: 'Arabic',
    nativeName: 'العربية',
    locale: Locale('ar', 'SA'),
  ),
  AppLanguage(
    code: 'fr',
    name: 'French',
    nativeName: 'Français',
    locale: Locale('fr', 'FR'),
  ),
  AppLanguage(
    code: 'es',
    name: 'Spanish',
    nativeName: 'Español',
    locale: Locale('es', 'ES'),
  ),
];

// Language notifier
class LanguageNotifier extends StateNotifier<AppLanguage> {
  static const String _languageKey = 'selected_language';

  LanguageNotifier() : super(availableLanguages.first) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    await reloadFromPrefs();
  }

  Future<void> reloadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'en';

      final language = availableLanguages.firstWhere(
        (lang) => lang.code == languageCode,
        orElse: () => availableLanguages.first,
      );

      if (language.code == state.code) return;
      state = language;
    } catch (e) {
      state = availableLanguages.first;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, language.code);
      state = language;
    } catch (e) {
      // Handle error silently or show a snackbar
    }
  }

  Future<void> setLanguageByCode(String code) async {
    final language = availableLanguages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => availableLanguages.first,
    );
    await setLanguage(language);
  }
}

// Providers
final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>(
  (ref) => LanguageNotifier(),
);

// Helper provider for locale
final localeProvider = Provider<Locale>((ref) {
  final language = ref.watch(languageProvider);
  return language.locale;
});

// Helper provider for language name
final languageNameProvider = Provider<String>((ref) {
  final language = ref.watch(languageProvider);
  return language.nativeName;
});

// Helper provider for RTL direction
final isRTLProvider = Provider<bool>((ref) {
  final language = ref.watch(languageProvider);
  return language.code == 'ar';
});
