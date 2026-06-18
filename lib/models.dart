// Modelli dei dati Xtream Codes di SCPTV.
//
// I campi dell'API possono arrivare come String o numero: li normalizziamo
// sempre a String con interpolazione.

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
}
