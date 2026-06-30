import 'dart:async';

import 'package:http/http.dart' as http;

import '../models.dart';
import '../xtream_api.dart' show ApiException;
import 'catalog_source.dart';
import 'settings_store.dart';

class _Parsed {
  final List<XtLive> live;
  final List<XtVod> vod;
  final List<XtCategory> liveCats;
  final List<XtCategory> vodCats;
  const _Parsed(this.live, this.vod, this.liveCats, this.vodCats);
}

/// Sorgente da playlist M3U/M3U8: lista piatta (niente serie strutturate né EPG).
/// La playlist viene scaricata e parsata una sola volta (cache).
class M3uSource implements CatalogSource {
  final String m3uUrl;
  final String userAgent;

  M3uSource({required this.m3uUrl, required this.userAgent});

  factory M3uSource.fromSettings() {
    final s = SettingsStore.instance;
    return M3uSource(m3uUrl: s.m3uUrl, userAgent: s.userAgent);
  }

  Future<_Parsed>? _cache;

  Map<String, String> get _headers => {'User-Agent': userAgent};

  static final RegExp _vodExt =
      RegExp(r'\.(mp4|mkv|avi|mov|m4v|flv|webm)(\?.*)?$', caseSensitive: false);

  bool _isVod(String url) =>
      url.contains('/movie/') || url.contains('/series/') || _vodExt.hasMatch(url);

  Future<_Parsed> _load() => _cache ??= _fetchAndParse();

  Future<_Parsed> _fetchAndParse() async {
    http.Response res;
    try {
      res = await http
          .get(Uri.parse(m3uUrl), headers: _headers)
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _cache = null;
      throw ApiException('Il server non risponde. Controlla l\'URL M3U.');
    } catch (_) {
      _cache = null;
      throw ApiException('Impossibile scaricare la playlist M3U.');
    }
    if (res.statusCode != 200) {
      _cache = null;
      throw ApiException('Errore nel download M3U (HTTP ${res.statusCode}).');
    }
    if (!res.body.trimLeft().startsWith('#EXTM3U')) {
      _cache = null;
      throw ApiException('La risposta non è una playlist M3U valida.');
    }
    return _parse(res.body);
  }

  _Parsed _parse(String body) {
    final live = <XtLive>[];
    final vod = <XtVod>[];
    final liveCatSet = <String>{};
    final vodCatSet = <String>{};

    String? name, logo, group, tvgId;
    for (final raw in body.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTINF')) {
        name = _afterComma(line);
        logo = _attr(line, 'tvg-logo');
        group = _attr(line, 'group-title');
        tvgId = _attr(line, 'tvg-id');
      } else if (line.startsWith('#')) {
        continue; // altri tag (#EXTGRP, #EXTVLCOPT, ecc.)
      } else {
        final url = line;
        final n = (name == null || name.isEmpty) ? 'Senza nome' : name;
        final g = (group == null || group.isEmpty) ? 'Senza categoria' : group;
        final lg = logo ?? '';
        if (_isVod(url)) {
          vodCatSet.add(g);
          vod.add(XtVod(
            streamId: url,
            name: n,
            icon: lg,
            categoryId: g,
            ext: _extOf(url),
            url: url,
          ));
        } else {
          liveCatSet.add(g);
          live.add(XtLive(
            streamId: url,
            name: n,
            icon: lg,
            categoryId: g,
            epgChannelId: tvgId ?? '',
            url: url,
          ));
        }
        name = logo = group = tvgId = null;
      }
    }

    List<XtCategory> cats(Set<String> s) =>
        (s.toList()..sort()).map((e) => XtCategory(id: e, name: e)).toList();
    return _Parsed(live, vod, cats(liveCatSet), cats(vodCatSet));
  }

  static String _afterComma(String extinf) {
    final i = extinf.lastIndexOf(',');
    return i >= 0 ? extinf.substring(i + 1).trim() : '';
  }

  static String? _attr(String line, String key) =>
      RegExp('$key="([^"]*)"').firstMatch(line)?.group(1);

  static String _extOf(String url) =>
      _vodExt.firstMatch(url)?.group(1)?.toLowerCase() ?? 'mp4';

  // --- CatalogSource ---
  @override
  Future<Map<String, dynamic>> userInfo() async {
    final p = await _load();
    return {'status': 'M3U OK', 'count': p.live.length + p.vod.length};
  }

  @override
  Future<List<XtCategory>> liveCategories() async => (await _load()).liveCats;
  @override
  Future<List<XtLive>> liveStreams() async => (await _load()).live;
  @override
  Future<List<XtCategory>> vodCategories() async => (await _load()).vodCats;
  @override
  Future<List<XtVod>> vodStreams() async => (await _load()).vod;

  @override
  Future<List<XtCategory>> seriesCategories() async => const <XtCategory>[];
  @override
  Future<List<XtSeries>> seriesList() async => const <XtSeries>[];
  @override
  Future<XtSeriesInfo> seriesInfo(String seriesId) async => XtSeriesInfo.empty;
  @override
  Future<XtVodInfo> vodInfo(String streamId) async => XtVodInfo.empty;
  @override
  Future<List<XtEpg>> shortEpg(String streamId, {int limit = 2}) async =>
      const <XtEpg>[];
  @override
  Future<List<XtEpg>> fullEpg(String streamId) async => const <XtEpg>[];

  @override
  String liveUrl(XtLive c) => c.url;
  @override
  String vodUrl(XtVod v) => v.url;
  @override
  String episodeUrl(XtEpisode e) => '';

  @override
  bool get supportsSeries => false;
  @override
  bool get supportsEpg => false;
}
