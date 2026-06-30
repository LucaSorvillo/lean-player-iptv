import '../models.dart';
import 'catalog_repository.dart';

/// Coppia "ora in onda" / "a seguire" per un canale.
class EpgNowNext {
  final XtEpg? now;
  final XtEpg? next;
  const EpgNowNext(this.now, this.next);

  bool get isEmpty => now == null && next == null;
}

/// Recupera e mette in cache il palinsesto dei canali live.
///
/// Cache per `streamId` con TTL breve, e dedup delle richieste in volo: la riga
/// del canale può chiedere l'EPG senza martellare il server allo scroll.
class EpgService {
  EpgService._();
  static final EpgService instance = EpgService._();

  final Map<String, List<XtEpg>> _cache = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Future<List<XtEpg>>> _inflight = {};
  static const _ttl = Duration(minutes: 10);

  // Cache separata per il palinsesto completo (TTL più lungo: cambia di rado).
  final Map<String, List<XtEpg>> _fullCache = {};
  final Map<String, DateTime> _fullFetchedAt = {};
  final Map<String, Future<List<XtEpg>>> _fullInflight = {};
  static const _fullTtl = Duration(minutes: 30);

  Future<List<XtEpg>> _listing(String streamId) {
    final at = _fetchedAt[streamId];
    if (at != null &&
        _cache.containsKey(streamId) &&
        DateTime.now().difference(at) < _ttl) {
      return Future.value(_cache[streamId]!);
    }
    return _inflight[streamId] ??=
        CatalogRepository.instance.shortEpg(streamId, limit: 12).then((list) {
      _cache[streamId] = list;
      _fetchedAt[streamId] = DateTime.now();
      _inflight.remove(streamId);
      return list;
    }).catchError((Object e) {
      _inflight.remove(streamId);
      throw e;
    });
  }

  /// Lista (in cache) dei programmi del canale: il corrente + i successivi.
  Future<List<XtEpg>> listing(String streamId) => _listing(streamId);

  /// Palinsesto completo del canale (cache separata, TTL più lungo). Usato
  /// dalla guida programmi.
  Future<List<XtEpg>> fullListing(String streamId) {
    final at = _fullFetchedAt[streamId];
    if (at != null &&
        _fullCache.containsKey(streamId) &&
        DateTime.now().difference(at) < _fullTtl) {
      return Future.value(_fullCache[streamId]!);
    }
    return _fullInflight[streamId] ??=
        CatalogRepository.instance.fullEpg(streamId).then((list) {
      _fullCache[streamId] = list;
      _fullFetchedAt[streamId] = DateTime.now();
      _fullInflight.remove(streamId);
      return list;
    }).catchError((Object e) {
      _fullInflight.remove(streamId);
      throw e;
    });
  }

  /// Svuota la cache EPG (es. dopo un cambio di sorgente/impostazioni).
  void clear() {
    _cache.clear();
    _fetchedAt.clear();
    _inflight.clear();
    _fullCache.clear();
    _fullFetchedAt.clear();
    _fullInflight.clear();
  }

  /// "Ora in onda" + "a seguire" per un canale (lista vuota → entrambi null).
  Future<EpgNowNext> nowNext(String streamId) async {
    final list = await _listing(streamId);
    if (list.isEmpty) return const EpgNowNext(null, null);
    final now = DateTime.now();
    XtEpg? current;
    XtEpg? upcoming;
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      final s = e.start, en = e.end;
      if (s == null || en == null) continue;
      if (!now.isBefore(s) && now.isBefore(en)) {
        current = e;
        if (i + 1 < list.length) upcoming = list[i + 1];
        break;
      }
      if (now.isBefore(s)) {
        upcoming ??= e; // primo programma futuro (usato se non c'è "ora")
      }
    }
    if (current == null) {
      for (final e in list) {
        if (e.nowPlaying) {
          current = e;
          break;
        }
      }
    }
    return EpgNowNext(current, upcoming);
  }
}
