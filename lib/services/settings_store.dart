import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Impostazioni dell'utente (credenziali + User-Agent), persistite con
/// `shared_preferences`. Due modalità: `xtream` (server+user+pass) o `m3u` (URL).
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _kMode = 'set_mode';
  static const _kServer = 'set_server';
  static const _kUser = 'set_user';
  static const _kPass = 'set_pass';
  static const _kM3u = 'set_m3u';
  static const _kUa = 'set_ua';

  SharedPreferences? _prefs;

  String mode = 'xtream'; // 'xtream' | 'm3u'
  String serverUrl = '';
  String username = '';
  String password = '';
  String m3uUrl = '';
  String userAgent = ScptvConfig.defaultUserAgent;

  bool get isM3u => mode == 'm3u';

  /// True se ci sono dati sufficienti per partire (decide il primo avvio).
  bool get isConfigured => isM3u
      ? m3uUrl.isNotEmpty
      : serverUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    mode = p.getString(_kMode) ?? 'xtream';
    serverUrl = p.getString(_kServer) ?? '';
    username = p.getString(_kUser) ?? '';
    password = p.getString(_kPass) ?? '';
    m3uUrl = p.getString(_kM3u) ?? '';
    userAgent = p.getString(_kUa) ?? ScptvConfig.defaultUserAgent;
    notifyListeners();
  }

  Future<void> save({
    required String mode,
    required String serverUrl,
    required String username,
    required String password,
    required String m3uUrl,
    required String userAgent,
  }) async {
    this.mode = mode == 'm3u' ? 'm3u' : 'xtream';
    this.serverUrl = normalizeBaseUrl(serverUrl);
    this.username = username.trim();
    this.password = password.trim();
    this.m3uUrl = m3uUrl.trim();
    this.userAgent =
        userAgent.trim().isEmpty ? ScptvConfig.defaultUserAgent : userAgent.trim();
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(_kMode, this.mode);
    await p.setString(_kServer, this.serverUrl);
    await p.setString(_kUser, this.username);
    await p.setString(_kPass, this.password);
    await p.setString(_kM3u, this.m3uUrl);
    await p.setString(_kUa, this.userAgent);
    notifyListeners();
  }

  /// Aggiunge `http://` se manca lo schema e toglie eventuali `/` finali.
  static String normalizeBaseUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
