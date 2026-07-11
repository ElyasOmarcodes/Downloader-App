import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user settings (download concurrency per network, language).
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _kWifi = 'concurrent_wifi';
  static const _kMobile = 'concurrent_mobile';
  static const _kLang = 'language_code';

  SharedPreferences? _prefs;

  int _wifiConcurrency = 3;
  int _mobileConcurrency = 1;
  String _languageCode = 'ps'; // Pashto by default.

  int get wifiConcurrency => _wifiConcurrency;
  int get mobileConcurrency => _mobileConcurrency;
  String get languageCode => _languageCode;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _wifiConcurrency = _prefs!.getInt(_kWifi) ?? 3;
    _mobileConcurrency = _prefs!.getInt(_kMobile) ?? 1;
    _languageCode = _prefs!.getString(_kLang) ?? 'ps';
  }

  Future<void> setWifiConcurrency(int value) async {
    _wifiConcurrency = value.clamp(1, 6);
    await _prefs?.setInt(_kWifi, _wifiConcurrency);
    notifyListeners();
  }

  Future<void> setMobileConcurrency(int value) async {
    _mobileConcurrency = value.clamp(1, 6);
    await _prefs?.setInt(_kMobile, _mobileConcurrency);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    await _prefs?.setString(_kLang, code);
    notifyListeners();
  }
}
