import '../models.dart';
import '../xtream_api.dart';
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

  static CatalogSource _build() => SettingsStore.instance.isM3u
      ? M3uSource.fromSettings()
      : XtreamApi.fromSettings();

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
    _source = _build();
    refresh();
    EpgService.instance.clear();
  }
}
