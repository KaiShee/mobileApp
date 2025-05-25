import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  static const String langKey = 'language_key';
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String langCode = prefs.getString(langKey) ?? 'en';
      _currentLocale = Locale(langCode);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading language preferences: $e');
      // Default to English if there's an error
      _currentLocale = const Locale('en');
      notifyListeners();
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    try {
      if (!['en', 'zh'].contains(languageCode)) {
        throw Exception('Unsupported language code: $languageCode');
      }
      
      _currentLocale = Locale(languageCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(langKey, languageCode);
      notifyListeners();
    } catch (e) {
      debugPrint('Error changing language: $e');
      // Keep the current locale if there's an error
      notifyListeners();
    }
  }

  bool isCurrentLanguage(String languageCode) {
    return _currentLocale.languageCode == languageCode;
  }

  String getCurrentLanguageName() {
    switch (_currentLocale.languageCode) {
      case 'zh':
        return '中文';
      case 'en':
      default:
        return 'English';
    }
  }
} 