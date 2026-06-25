import '../models.dart';
import '../xtream_api.dart';

/// Cache in memoria (di sessione) di categorie e liste.
///
/// La prima richiesta scarica dal server, le successive riusano il risultato:
/// così cambiare scheda o aprire la ricerca non riscarica nulla. I fallimenti
/// NON vengono messi in cache (la richiesta successiva ritenta). `refresh()`
/// invalida tutto, per il pull-to-refresh.
class CatalogRepository {
  CatalogRepository._();
  static final CatalogRepository instance = CatalogRepository._();

  final XtreamApi api = XtreamApi();

  Future<List<XtLive>>? _live;
  Future<List<XtVod>>? _vod;
  Future<List<XtSeries>>? _series;
  Future<List<XtCategory>>? _liveCats;
  Future<List<XtCategory>>? _vodCats;
  Future<List<XtCategory>>? _seriesCats;

  Future<List<XtLive>> live() {
    return _live ??= api.liveStreams().catchError((Object e) {
      _live = null;
      throw e;
    });
  }

  Future<List<XtVod>> vod() {
    return _vod ??= api.vodStreams().catchError((Object e) {
      _vod = null;
      throw e;
    });
  }

  Future<List<XtSeries>> series() {
    return _series ??= api.seriesList().catchError((Object e) {
      _series = null;
      throw e;
    });
  }

  Future<List<XtCategory>> liveCategories() {
    return _liveCats ??= api.liveCategories().catchError((Object e) {
      _liveCats = null;
      throw e;
    });
  }

  Future<List<XtCategory>> vodCategories() {
    return _vodCats ??= api.vodCategories().catchError((Object e) {
      _vodCats = null;
      throw e;
    });
  }

  Future<List<XtCategory>> seriesCategories() {
    return _seriesCats ??= api.seriesCategories().catchError((Object e) {
      _seriesCats = null;
      throw e;
    });
  }

  /// Invalida tutta la cache (pull-to-refresh).
  void refresh() {
    _live = null;
    _vod = null;
    _series = null;
    _liveCats = null;
    _vodCats = null;
    _seriesCats = null;
  }
}
