import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class SecureStorageService {
  static const _keyApiKey = 'ollama_cloud_api_key';
  static const _keyBaseUrl = 'ollama_cloud_base_url';
  static const _keyModelName = 'ollama_cloud_model_name';
  static const _keyOfflineMode = 'foodies_offline_mode';

  static const String defaultBaseUrl = 'https://ollama.com/api';
  static const String defaultModelName = 'gemma4:31b';

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _prefs;

  SecureStorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      AppLogger.error('Failed to initialize SharedPreferences', error: e);
    }
  }

  /// Store API key securely with dual SharedPreferences fallback
  Future<void> saveApiKey(String apiKey) async {
    final clean = apiKey.trim();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_keyApiKey, clean);

    try {
      await _secureStorage.write(key: _keyApiKey, value: clean);
    } catch (e) {
      AppLogger.error('Error saving API key to secure storage, preserved in preferences', error: e);
    }
  }

  /// Read API key from secure storage or SharedPreferences (entered in-app)
  Future<String?> getApiKey() async {
    try {
      final key = await _secureStorage.read(key: _keyApiKey);
      if (key != null && key.trim().isNotEmpty) return key.trim();
    } catch (e) {
      AppLogger.error('Error reading API key from secure storage', error: e);
    }

    _prefs ??= await SharedPreferences.getInstance();
    final prefKey = _prefs!.getString(_keyApiKey);
    if (prefKey != null && prefKey.trim().isNotEmpty) {
      return prefKey.trim();
    }

    return null;
  }

  /// Delete API key
  Future<void> clearApiKey() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_keyApiKey);

    try {
      await _secureStorage.delete(key: _keyApiKey);
    } catch (e) {
      AppLogger.error('Error deleting API key', error: e);
    }
  }

  /// Base URL
  Future<void> saveBaseUrl(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_keyBaseUrl, clean);
  }

  Future<String> getBaseUrl() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getString(_keyBaseUrl) ?? defaultBaseUrl;
  }

  /// Model name
  Future<void> saveModelName(String model) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_keyModelName, model.trim());
  }

  Future<String> getModelName() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getString(_keyModelName) ?? defaultModelName;
  }

  /// Offline mode
  Future<void> setOfflineMode(bool offline) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_keyOfflineMode, offline);
  }

  Future<bool> isOfflineMode() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getBool(_keyOfflineMode) ?? false;
  }
}
