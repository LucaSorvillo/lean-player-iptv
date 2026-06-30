// Modelli dei dati Xtream Codes di SCPTV.
//
// I campi dell'API possono arrivare come String o numero: li normalizziamo
// sempre a String con interpolazione.

import 'dart:convert';

class XtCategory {
  final String id;
  final String name;
  const XtCategory({required this.id, required this.name});

  factory XtCategory.fromJson(Map<String, dynamic> j) => XtCategory(
        id: '${j['category_id']}',
        name: '${j['category_name'] ?? ''}',
      );
}

class XtLive {
  final String streamId;
  final String name;
  final String icon;
  final String categoryId;
  final String epgChannelId;

  /// URL diretto (modalità M3U). Vuoto in Xtream: l'URL si costruisce da streamId.
  final String url;

  const XtLive({
    required this.streamId,
    required this.name,
    required this.icon,
    required this.categoryId,
    required this.epgChannelId,
    this.url = '',
  });

  factory XtLive.fromJson(Map<String, dynamic> j) => XtLive(
        streamId: '${j['stream_id']}',
        name: '${j['name'] ?? ''}',
        icon: '${j['stream_icon'] ?? ''}',
        categoryId: '${j['category_id'] ?? ''}',
        epgChannelId: '${j['epg_channel_id'] ?? ''}',
        url: '${j['url'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'stream_id': streamId,
        'name': name,
        'stream_icon': icon,
        'category_id': categoryId,
        'epg_channel_id': epgChannelId,
        'url': url,
      };
}

class XtVod {
  final String streamId;
  final String name;
  final String icon;
  final String categoryId;
  final String ext;

  /// URL diretto (modalità M3U). Vuoto in Xtream: l'URL si costruisce da streamId.
  final String url;

  const XtVod({
    required this.streamId,
    required this.name,
    required this.icon,
    required this.categoryId,
    required this.ext,
    this.url = '',
  });

  factory XtVod.fromJson(Map<String, dynamic> j) => XtVod(
        streamId: '${j['stream_id']}',
        name: '${j['name'] ?? ''}',
        icon: '${j['stream_icon'] ?? ''}',
        categoryId: '${j['category_id'] ?? ''}',
        ext: '${j['container_extension'] ?? 'mp4'}',
        url: '${j['url'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'stream_id': streamId,
        'name': name,
        'stream_icon': icon,
        'category_id': categoryId,
        'container_extension': ext,
        'url': url,
      };
}

class XtSeries {
  final String seriesId;
  final String name;
  final String cover;
  final String categoryId;

  const XtSeries({
    required this.seriesId,
    required this.name,
    required this.cover,
    required this.categoryId,
  });

  factory XtSeries.fromJson(Map<String, dynamic> j) => XtSeries(
        seriesId: '${j['series_id']}',
        name: '${j['name'] ?? ''}',
        cover: '${j['cover'] ?? ''}',
        categoryId: '${j['category_id'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'series_id': seriesId,
        'name': name,
        'cover': cover,
        'category_id': categoryId,
      };
}

class XtEpisode {
  final String id;
  final String title;
  final String ext;
  final int season; // 0 = sconosciuta / contenuti speciali
  final int episodeNum; // 0 = sconosciuto
  final String image; // copertina episodio; '' = assente
  final String duration; // es. "00:42:10"
  final String plot; // sinossi breve

  const XtEpisode({
    required this.id,
    required this.title,
    required this.ext,
    this.season = 0,
    this.episodeNum = 0,
    this.image = '',
    this.duration = '',
    this.plot = '',
  });

  // Gestisce due forme: la risposta API (campi ricchi annidati in `info`) e il
  // JSON salvato da `toJson` per il "continua a guardare" (chiavi piatte).
  factory XtEpisode.fromJson(Map<String, dynamic> j) {
    final info = j['info'];
    final im =
        info is Map ? info.cast<String, dynamic>() : const <String, dynamic>{};
    return XtEpisode(
      id: '${j['id']}',
      title: '${j['title'] ?? 'Episodio'}',
      ext: '${j['container_extension'] ?? 'mp4'}',
      season: int.tryParse('${j['season'] ?? im['season'] ?? 0}') ?? 0,
      episodeNum: int.tryParse('${j['episode_num'] ?? 0}') ?? 0,
      image: _firstNonEmpty(
          [j['image'], im['movie_image'], im['cover_big'], im['cover']]),
      duration: '${j['duration'] ?? im['duration'] ?? ''}',
      plot: '${j['plot'] ?? im['plot'] ?? im['overview'] ?? ''}',
    );
  }

  XtEpisode copyWith({int? season}) => XtEpisode(
        id: id,
        title: title,
        ext: ext,
        season: season ?? this.season,
        episodeNum: episodeNum,
        image: image,
        duration: duration,
        plot: plot,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'container_extension': ext,
        'season': season,
        'episode_num': episodeNum,
        if (image.isNotEmpty) 'image': image,
        if (duration.isNotEmpty) 'duration': duration,
        if (plot.isNotEmpty) 'plot': plot,
      };
}

/// Prima stringa non vuota della lista (scarta `null` e "null"); '' se nessuna.
String _firstNonEmpty(List<dynamic> vals) {
  for (final v in vals) {
    final s = '${v ?? ''}'.trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return '';
}

/// Dettagli di un film (da `get_vod_info` → `info`).
class XtVodInfo {
  final String plot;
  final String genre;
  final String year;
  final String rating;
  final String duration;

  const XtVodInfo({
    this.plot = '',
    this.genre = '',
    this.year = '',
    this.rating = '',
    this.duration = '',
  });

  static const XtVodInfo empty = XtVodInfo();

  factory XtVodInfo.fromInfo(Map<String, dynamic> j) => XtVodInfo(
        plot: '${j['plot'] ?? j['description'] ?? ''}',
        genre: '${j['genre'] ?? ''}',
        year: '${j['year'] ?? j['releasedate'] ?? ''}',
        rating: '${j['rating'] ?? ''}',
        duration: '${j['duration'] ?? ''}',
      );
}

/// Dettagli di una serie: trama + episodi (da `get_series_info`).
class XtSeriesInfo {
  final String plot;
  final List<XtEpisode> episodes;

  const XtSeriesInfo({this.plot = '', this.episodes = const []});

  static const XtSeriesInfo empty = XtSeriesInfo();

  /// Numeri di stagione presenti, ordinati crescenti.
  List<int> get seasons {
    final s = <int>{for (final e in episodes) e.season}.toList()..sort();
    return s;
  }
}

/// Etichetta leggibile di una stagione (0 = contenuti speciali).
String seasonLabel(int s) => s == 0 ? 'Speciali' : 'Stagione $s';

/// Decodifica un campo Xtream che di norma è base64 (titoli/descrizioni EPG).
/// Se non è base64 valido, restituisce la stringa così com'è.
String decodeXtreamText(dynamic v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty) return '';
  try {
    return utf8.decode(base64.decode(base64.normalize(s)));
  } catch (_) {
    return s;
  }
}

DateTime? _epgTs(dynamic v) {
  final n = int.tryParse('${v ?? ''}');
  if (n == null || n == 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(n * 1000);
}

/// Voce di palinsesto (EPG). Da `get_short_epg` / `get_simple_data_table`.
class XtEpg {
  final String title;
  final String description;
  final DateTime? start;
  final DateTime? end;
  final bool nowPlaying;

  const XtEpg({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    required this.nowPlaying,
  });

  factory XtEpg.fromJson(Map<String, dynamic> j) => XtEpg(
        title: decodeXtreamText(j['title']),
        description: decodeXtreamText(j['description']),
        start: _epgTs(j['start_timestamp']),
        end: _epgTs(j['stop_timestamp']),
        nowPlaying: '${j['now_playing'] ?? ''}' == '1',
      );

  /// È il programma in onda adesso? (calcolato dagli orari; fallback su now_playing)
  bool get isNow {
    if (start == null || end == null) return nowPlaying;
    final now = DateTime.now();
    return !now.isBefore(start!) && now.isBefore(end!);
  }

  /// Orario "HH:MM" di inizio, vuoto se assente.
  String get startHHmm {
    final s = start;
    if (s == null) return '';
    return '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
  }
}
