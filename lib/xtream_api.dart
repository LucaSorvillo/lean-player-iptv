import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'services/catalog_source.dart';
import 'services/settings_store.dart';

/// Errore "parlante" delle chiamate API: il messaggio è già pronto per l'utente.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Client per l'API Xtream Codes (player_api.php).
///
/// L'`userAgent` dell'istanza viene inviato su tutte le richieste (e, tramite il
/// player, anche allo streaming). Gli URL puntano al primo hop; il server può
/// rispondere con redirect 302 + token che il player segue.
class XtreamApi implements CatalogSource {
  final String baseUrl;
  final String username;
  final String password;
  final String userAgent;

  XtreamApi({
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.userAgent,
  });

  /// Costruisce il client dalle impostazioni salvate.
  factory XtreamApi.fromSettings() {
    final s = SettingsStore.instance;
    return XtreamApi(
      baseUrl: s.serverUrl,
      username: s.username,
      password: s.password,
      userAgent: s.userAgent,
    );
  }

  String get _base => SettingsStore.normalizeBaseUrl(baseUrl);
  Map<String, String> get _headers => {'User-Agent': userAgent};

  Uri _api(Map<String, String> extra) =>
      Uri.parse('$_base/player_api.php').replace(queryParameters: {
        'username': username,
        'password': password,
        ...extra,
      });

  Future<dynamic> _getJson(Uri uri) async {
    http.Response res;
    try {
      res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException('Il server non risponde. Controlla la connessione.');
    } catch (_) {
      throw ApiException(
          'Impossibile contattare il server. Controlla la connessione.');
    }
    if (res.statusCode != 200) {
      throw ApiException('Errore del server (HTTP ${res.statusCode}).');
    }
    try {
      return jsonDecode(res.body);
    } catch (_) {
      throw ApiException('Risposta non valida dal server.');
    }
  }

  /// Login / info account: ritorna `user_info` (auth, status, exp_date, ...).
  @override
  Future<Map<String, dynamic>> userInfo() async {
    final data = await _getJson(_api({}));
    if (data is Map<String, dynamic>) {
      return (data['user_info'] as Map?)?.cast<String, dynamic>() ?? {};
    }
    return {};
  }

  Future<List<XtCategory>> _categories(String action) async {
    final data = await _getJson(_api({'action': action}));
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => XtCategory.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  @override
  Future<List<XtCategory>> liveCategories() =>
      _categories('get_live_categories');
  @override
  Future<List<XtCategory>> vodCategories() => _categories('get_vod_categories');
  @override
  Future<List<XtCategory>> seriesCategories() =>
      _categories('get_series_categories');

  @override
  Future<List<XtLive>> liveStreams({String? categoryId}) async {
    final params = {'action': 'get_live_streams'};
    if (categoryId != null) params['category_id'] = categoryId;
    final data = await _getJson(_api(params));
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => XtLive.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  @override
  Future<List<XtVod>> vodStreams({String? categoryId}) async {
    final params = {'action': 'get_vod_streams'};
    if (categoryId != null) params['category_id'] = categoryId;
    final data = await _getJson(_api(params));
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => XtVod.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  @override
  Future<List<XtSeries>> seriesList({String? categoryId}) async {
    final params = {'action': 'get_series'};
    if (categoryId != null) params['category_id'] = categoryId;
    final data = await _getJson(_api(params));
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => XtSeries.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  /// Episodi di una serie (get_series_info → mappa stagione→episodi, appiattita).
  @override
  Future<List<XtEpisode>> seriesInfo(String seriesId) async {
    final data = await _getJson(_api({
      'action': 'get_series_info',
      'series_id': seriesId,
    }));
    final out = <XtEpisode>[];
    if (data is Map && data['episodes'] is Map) {
      for (final season in (data['episodes'] as Map).values) {
        if (season is List) {
          for (final e in season) {
            if (e is Map) {
              out.add(XtEpisode.fromJson(e.cast<String, dynamic>()));
            }
          }
        }
      }
    }
    return out;
  }

  /// Palinsesto di un canale live. Prova `get_short_epg` (leggero: ora + a
  /// seguire); se vuoto/non supportato ricade su `get_simple_data_table`
  /// (l'endpoint usato dall'app ufficiale). Lista ordinata per orario.
  @override
  Future<List<XtEpg>> shortEpg(String streamId, {int limit = 2}) async {
    for (final action in const ['get_short_epg', 'get_simple_data_table']) {
      final params = {'action': action, 'stream_id': streamId};
      if (action == 'get_short_epg') params['limit'] = '$limit';
      dynamic data;
      try {
        data = await _getJson(_api(params));
      } catch (_) {
        continue; // prova il fallback
      }
      final listings = (data is Map) ? data['epg_listings'] : null;
      if (listings is List && listings.isNotEmpty) {
        final out = listings
            .whereType<Map>()
            .map((e) => XtEpg.fromJson(e.cast<String, dynamic>()))
            .toList()
          ..sort((a, b) =>
              (a.start ?? DateTime(1970)).compareTo(b.start ?? DateTime(1970)));
        if (out.isNotEmpty) return out;
      }
    }
    return [];
  }

  // --- URL di streaming (primo hop; il server fa redirect 302 + token) ---
  @override
  String liveUrl(XtLive c) => '$_base/live/$username/$password/${c.streamId}.ts';
  @override
  String vodUrl(XtVod v) =>
      '$_base/movie/$username/$password/${v.streamId}.${v.ext}';
  @override
  String episodeUrl(XtEpisode e) =>
      '$_base/series/$username/$password/${e.id}.${e.ext}';

  @override
  bool get supportsSeries => true;
  @override
  bool get supportsEpg => true;
}
