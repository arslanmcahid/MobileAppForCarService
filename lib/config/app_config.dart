import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/database_helper.dart';

class AppConfig {
  static late SharedPreferences _prefs;
  static DatabaseHelper? _databaseHelper;

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Web platformunda SQLite kullanamayız
    if (!kIsWeb) {
      _databaseHelper = DatabaseHelper.instance;
      await _databaseHelper!.database; // Veritabanını başlat
    }
  }

  static SharedPreferences get prefs => _prefs;
  static DatabaseHelper? get database => _databaseHelper;

  // Web platformu kontrolü
  static bool get isWebPlatform => kIsWeb;

  // Uygulama ayarları
  static const String keyFirstTime = 'first_time';
  static const String keyDarkMode = 'dark_mode';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyDefaultReminder = 'default_reminder_days';

  // Varsayılan değerler
  static bool get isFirstTime => _prefs.getBool(keyFirstTime) ?? true;
  static bool get isDarkMode => _prefs.getBool(keyDarkMode) ?? false;
  static bool get notificationsEnabled => _prefs.getBool(keyNotificationsEnabled) ?? true;
  static int get defaultReminderDays => _prefs.getInt(keyDefaultReminder) ?? 7;

  // Ayarları kaydet
  static Future<void> setFirstTime(bool value) => _prefs.setBool(keyFirstTime, value);
  static Future<void> setDarkMode(bool value) => _prefs.setBool(keyDarkMode, value);
  static Future<void> setNotificationsEnabled(bool value) => _prefs.setBool(keyNotificationsEnabled, value);
  static Future<void> setDefaultReminderDays(int value) => _prefs.setInt(keyDefaultReminder, value);
} 