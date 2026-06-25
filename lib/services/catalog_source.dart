import '../models.dart';

/// Sorgente del catalogo IPTV. Due implementazioni:
/// - `XtreamApi` (player_api.php): catalogo completo + EPG + serie;
/// - `M3uSource` (playlist M3U): lista piatta, niente serie/EPG.
///
/// La UI lavora su questa interfaccia, indipendente dalla sorgente attiva.
abstract class CatalogSource {
  /// Validazione/login (usata dal "Prova connessione"). Xtream → `user_info`;
  /// M3U → mappa con esito sintetico (es. conteggio elementi).
  Future<Map<String, dynamic>> userInfo();

  Future<List<XtCategory>> liveCategories();
  Future<List<XtLive>> liveStreams();
  Future<List<XtCategory>> vodCategories();
  Future<List<XtVod>> vodStreams();
  Future<List<XtCategory>> seriesCategories();
  Future<List<XtSeries>> seriesList();
  Future<XtSeriesInfo> seriesInfo(String seriesId);
  Future<XtVodInfo> vodInfo(String streamId);
  Future<List<XtEpg>> shortEpg(String streamId, {int limit});

  /// URL riproducibile dell'elemento (Xtream lo costruisce; M3U è diretto).
  String liveUrl(XtLive c);
  String vodUrl(XtVod v);
  String episodeUrl(XtEpisode e);

  bool get supportsSeries;
  bool get supportsEpg;
}
