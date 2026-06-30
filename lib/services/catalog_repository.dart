import '../models.dart';
import '../xtream_api.dart';
import 'catalog_cache_store.dart';
import 'catalog_source.dart';
import 'epg_service.dart';
import 'm3u_source.dart';
import 'settings_store.dart';

/// Cache in memoria (di sessione) di categorie e liste, sopra una [CatalogSource]
/// (Xtream o M3U) scelta dalle impostazioni.
///
/// La prima richiesta scarica, le successive riusano; i fallimenti NON vanno in
/// cache (la richiesta successiva ritenta). `refresh()` invalida le liste;
/// `rebuild()` ricrea la sorgente dopo un cambio di impostazioni.
class CatalogRepository {
  CatalogRepository._();
  static final CatalogRepository instance = CatalogRepository._();

  CatalogSource _source = _build();

  static CatalogSource _build() {
    final inner = SettingsStore.instance.isM3u
        ? M3uSource.fromSettings()
        : XtreamApi.fromSettings();
    return _CachingCatalogSource(inner, CatalogCacheStore(_cacheNamespace()));
  }

  /// Chiave di cache su disco: isola profili/playlist diversi.
  static String _cacheNamespace() {
    final s = SettingsStore.instance;
    final raw = s.isM3u ? 'm3u|${s.m3uUrl}' : 'xt|${s.serverUrl}|${s.username}';
    return raw.hashCode.toUnsigned(32).toRadixString(16);
  }

  CatalogSource get source => _source;
  bool get supportsSeries => _source.supportsSeries;
  bool get supportsEpg => _source.supportsEpg;

  Future<List<XtLive>>? _live;
  Future<List<XtVod>>? _vod;
  Future<List<XtSeries>>? _series;
  Future<List<XtCategory>>? _liveCats;
  Future<List<XtCategory>>? _vodCats;
  Future<List<XtCategory>>? _seriesCats;

  Future<List<XtLive>> live() {
    return _live ??= _source.liveStreams().catchError((Object e) {
      _live = null;
      throw e;
    });
  }

  Future<List<XtVod>> vod() {
    return _vod ??= _source.vodStreams().catchError((Object e) {
      _vod = null;
      throw e;
    });
  }

  Future<List<XtSeries>> series() {
    return _series ??= _source.seriesList().catchError((Object e) {
      _series = null;
      throw e;
    });
  }

  Future<List<XtCategory>> liveCategories() {
    return _liveCats ??= _source.liveCategories().catchError((Object e) {
      _liveCats = null;
      throw e;
    });
  }

  Future<List<XtCategory>> vodCategories() {
    return _vodCats ??= _source.vodCategories().catchError((Object e) {
      _vodCats = null;
      throw e;
    });
  }

  Future<List<XtCategory>> seriesCategories() {
    return _seriesCats ??= _source.seriesCategories().catchError((Object e) {
      _seriesCats = null;
      throw e;
    });
  }

  Future<List<XtEpg>> shortEpg(String streamId, {int limit = 2}) =>
      _source.shortEpg(streamId, limit: limit);

  Future<List<XtEpg>> fullEpg(String streamId) => _source.fullEpg(streamId);

  String liveUrl(XtLive c) => _source.liveUrl(c);
  String vodUrl(XtVod v) => _source.vodUrl(v);
  String episodeUrl(XtEpisode e) => _source.episodeUrl(e);

  /// Invalida le liste in cache (pull-to-refresh).
  void refresh() {
    _live = null;
    _vod = null;
    _series = null;
    _liveCats = null;
    _vodCats = null;
    _seriesCats = null;
  }

  /// Ricrea la sorgente dalle impostazioni e svuota tutte le cache.
  void rebuild() {
    final old = _source;
    _source = _build();
    refresh();
    EpgService.instance.clear();
    if (old is _CachingCatalogSource) old.clearCache();
  }
}

/// Decoratore che persiste su disco le liste del catalogo: write-through sui
/// fetch riusciti e fallback al disco quando la rete fallisce (avvio offline).
class _CachingCatalogSource implements CatalogSource {
  _CachingCatalogSource(this._inner, this._cache);
  final CatalogSource _inner;
  final CatalogCacheStore _cache;

  Future<void> clearCache() => _cache.clear();

  Future<List<T>> _cached<T>(
    String key,
    Future<List<T>> Function() fetch,
    Map<String, dynamic> Function(T) toJson,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final fresh = await fetch();
      await _cache.saveList(key, fresh, toJson);
      return fresh;
    } catch (_) {
      final disk = await _cache.loadList(key, fromJson);
      if (disk != null) return disk; // fallback offline
      rethrow;
    }
  }

  @override
  Future<List<XtLive>> liveStreams() =>
      _cached('live', _inner.liveStreams, (e) => e.toJson(), XtLive.fromJson);
  @override
  Future<List<XtVod>> vodStreams() =>
      _cached('vod', _inner.vodStreams, (e) => e.toJson(), XtVod.fromJson);
  @override
  Future<List<XtSeries>> seriesList() =>
      _cached('series', _inner.seriesList, (e) => e.toJson(), XtSeries.fromJson);
  @override
  Future<List<XtCategory>> liveCategories() => _cached('live_cats',
      _inner.liveCategories, (e) => e.toJson(), XtCategory.fromJson);
  @override
  Future<List<XtCategory>> vodCategories() => _cached(
      'vod_cats', _inner.vodCategories, (e) => e.toJson(), XtCategory.fromJson);
  @override
  Future<List<XtCategory>> seriesCategories() => _cached('series_cats',
      _inner.seriesCategories, (e) => e.toJson(), XtCategory.fromJson);

  // Passthrough: dettagli/EPG/URL/flag non sono cachati su disco.
  @override
  Future<Map<String, dynamic>> userInfo() => _inner.userInfo();
  @override
  Future<XtSeriesInfo> seriesInfo(String seriesId) =>
      _inner.seriesInfo(seriesId);
  @override
  Future<XtVodInfo> vodInfo(String streamId) => _inner.vodInfo(streamId);
  @override
  Future<List<XtEpg>> shortEpg(String streamId, {int limit = 2}) =>
      _inner.shortEpg(streamId, limit: limit);
  @override
  Future<List<XtEpg>> fullEpg(String streamId) => _inner.fullEpg(streamId);
  @override
  String liveUrl(XtLive c) => _inner.liveUrl(c);
  @override
  String vodUrl(XtVod v) => _inner.vodUrl(v);
  @override
  String episodeUrl(XtEpisode e) => _inner.episodeUrl(e);
  @override
  bool get supportsSeries => _inner.supportsSeries;
  @override
  bool get supportsEpg => _inner.supportsEpg;
}
