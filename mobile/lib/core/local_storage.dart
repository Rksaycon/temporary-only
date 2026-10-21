import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Local storage service for persistent data
class LocalStorage {
  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _isDarkModeKey = 'is_dark_mode';
  static const String _localeKey = 'locale';

  static late SharedPreferences _prefs;
  static late Box<dynamic> _hiveBox;

  /// Initialize local storage
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await Hive.initFlutter();
    _hiveBox = await Hive.openBox('milaud_app');
  }

  /// Auth token methods
  static Future<void> saveAuthToken(String token) async {
    await _prefs.setString(_authTokenKey, token);
  }

  static String? getAuthToken() {
    return _prefs.getString(_authTokenKey);
  }

  static Future<void> clearAuthToken() async {
    await _prefs.remove(_authTokenKey);
  }

  /// User data methods
  static Future<void> saveUserData({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    await _prefs.setString(_userIdKey, userId);
    await _prefs.setString(_userNameKey, userName);
    await _prefs.setString(_userEmailKey, userEmail);
  }

  static Map<String, String?> getUserData() {
    return {
      'userId': _prefs.getString(_userIdKey),
      'userName': _prefs.getString(_userNameKey),
      'userEmail': _prefs.getString(_userEmailKey),
    };
  }

  static Future<void> clearUserData() async {
    await _prefs.remove(_userIdKey);
    await _prefs.remove(_userNameKey);
    await _prefs.remove(_userEmailKey);
  }

  /// App settings
  static Future<void> setFirstLaunch(bool isFirst) async {
    await _prefs.setBool(_isFirstLaunchKey, isFirst);
  }

  static bool isFirstLaunch() {
    return _prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  static Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(_isDarkModeKey, isDark);
  }

  static bool isDarkMode() {
    return _prefs.getBool(_isDarkModeKey) ?? false;
  }

  static Future<void> setLocale(String locale) async {
    await _prefs.setString(_localeKey, locale);
  }

  static String getLocale() {
    return _prefs.getString(_localeKey) ?? 'en';
  }

  /// Hive storage for complex data
  static Future<void> saveToHive(String key, dynamic value) async {
    await _hiveBox.put(key, value);
  }

  static dynamic getFromHive(String key) {
    return _hiveBox.get(key);
  }

  static Future<void> deleteFromHive(String key) async {
    await _hiveBox.delete(key);
  }

  /// Clear all data (logout)
  static Future<void> clearAll() async {
  await clearAuthToken();
  await clearUserData();
  await _prefs.remove(_isFirstLaunchKey);
  await _prefs.remove(_isDarkModeKey);
  await _prefs.remove(_localeKey);
  await _hiveBox.clear();
}
}
