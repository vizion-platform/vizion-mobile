import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../log.dart';

/// Guarda os tokens no armazenamento seguro do SO (Keystore no Android, Keychain no iOS).
/// Dados não sensíveis (nome, papel) continuam em SharedPreferences.
class TokenStore {
  static const _access = 'accessToken';
  static const _refresh = 'refreshToken';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> readAccess() => _read(_access);
  static Future<String?> readRefresh() => _read(_refresh);

  static Future<void> save({String? access, String? refresh}) async {
    try {
      if (access != null) await _storage.write(key: _access, value: access);
      if (refresh != null) await _storage.write(key: _refresh, value: refresh);
    } catch (e) {
      logDebug('Falha ao gravar tokens no armazenamento seguro: ${e.runtimeType}');
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _access);
      await _storage.delete(key: _refresh);
    } catch (e) {
      logDebug('Falha ao limpar tokens do armazenamento seguro: ${e.runtimeType}');
    }
  }

  /// Migra tokens que versões anteriores gravaram em texto puro no SharedPreferences.
  static Future<void> migrateFromPrefs(SharedPreferences prefs) async {
    final legacyAccess = prefs.getString(_access);
    final legacyRefresh = prefs.getString(_refresh);
    if (legacyAccess == null && legacyRefresh == null) return;
    await save(
      access: legacyAccess,
      refresh: (legacyRefresh != null && legacyRefresh.isNotEmpty) ? legacyRefresh : null,
    );
    await prefs.remove(_access);
    await prefs.remove(_refresh);
  }

  static Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      logDebug('Falha ao ler token do armazenamento seguro: ${e.runtimeType}');
      return null;
    }
  }
}
