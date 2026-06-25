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

  const XtLive({
    required this.streamId,
    required this.name,
    required this.icon,
    required this.categoryId,
    required this.epgChannelId,
  });

  factory XtLive.fromJson(Map<String, dynamic> j) => XtLive(
        streamId: '${j['stream_id']}',
        name: '${j['name'] ?? ''}',
        icon: '${j['stream_icon'] ?? ''}',
        categoryId: '${j['category_id'] ?? ''}',
        epgChannelId: '${j['epg_channel_id'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'stream_id': streamId,
        'name': name,
        'stream_icon': icon,
        'category_id': categoryId,
        'epg_channel_id': epgChannelId,
      };
}

class XtVod {
  final String streamId;
  final String name;
  final String icon;
  final String categoryId;
  final String ext;

  const XtVod({
    required this.streamId,
    required this.name,
    required this.icon,
    required this.categoryId,
    required this.ext,
  });

  factory XtVod.fromJson(Map<String, dynamic> j) => XtVod(
        streamId: '${j['stream_id']}',
        name: '${j['name'] ?? ''}',
        icon: '${j['stream_icon'] ?? ''}',
        categoryId: '${j['category_id'] ?? ''}',
        ext: '${j['container_extension'] ?? 'mp4'}',
      );

  Map<String, dynamic> toJson() => {
        'stream_id': streamId,
        'name': name,
        'stream_icon': icon,
        'category_id': categoryId,
        'container_extension': ext,
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

  const XtEpisode({required this.id, required this.title, required this.ext});

  factory XtEpisode.fromJson(Map<String, dynamic> j) => XtEpisode(
        id: '${j['id']}',
        title: '${j['title'] ?? 'Episodio'}',
        ext: '${j['container_extension'] ?? 'mp4'}',
      );
}

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
