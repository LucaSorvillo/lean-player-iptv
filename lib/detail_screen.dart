import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'services/catalog_repository.dart';
import 'services/favorites_store.dart';
import 'widgets/common.dart';

/// Pagina dettaglio in stile Netflix per film o serie: poster grande con
/// gradiente, Riproduci, "La mia lista", trama e (per le serie) gli episodi.
class DetailScreen extends StatefulWidget {
  final XtVod? movie;
  final XtSeries? series;

  const DetailScreen.movie(XtVod this.movie, {super.key}) : series = null;
  const DetailScreen.series(XtSeries this.series, {super.key}) : movie = null;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final CatalogRepository _repo = CatalogRepository.instance;

  bool get _isMovie => widget.movie != null;
  String get _title => _isMovie ? widget.movie!.name : widget.series!.name;
  String get _poster => _isMovie ? widget.movie!.icon : widget.series!.cover;
  IconData get _fallback => _isMovie ? Icons.movie : Icons.video_library;

  late final Future<XtVodInfo> _movieInfo = _isMovie
      ? _repo.source.vodInfo(widget.movie!.streamId)
      : Future.value(XtVodInfo.empty);
  late final Future<XtSeriesInfo> _seriesInfo = _isMovie
      ? Future.value(XtSeriesInfo.empty)
      : _repo.source.seriesInfo(widget.series!.seriesId);

  void _play(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(url: url, title: title)),
    );
  }

  Widget _favStar() => _isMovie
      ? FavStar(
          isFav: () => FavoritesStore.instance.isVodFav(widget.movie!.streamId),
          onToggle: () => FavoritesStore.instance.toggleVod(widget.movie!),
        )
      : FavStar(
          isFav: () =>
              FavoritesStore.instance.isSeriesFav(widget.series!.seriesId),
          onToggle: () => FavoritesStore.instance.toggleSeries(widget.series!),
        );

  Widget _myList() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _favStar(),
          const Text('La mia lista',
              style: TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      );

  Widget _actions({VoidCallback? onPlay}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Riproduci'),
            ),
          ),
          const SizedBox(width: 12),
          _myList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          if (_isMovie) ..._movieBody() else ..._seriesBody(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 440,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_poster.isNotEmpty)
            CachedNetworkImage(
              imageUrl: _poster,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              placeholder: (_, _) => Container(color: Colors.white10),
              errorWidget: (_, _, _) =>
                  Container(color: Colors.white10, child: Icon(_fallback, size: 64, color: Colors.white24)),
            )
          else
            Container(color: Colors.white10, child: Icon(_fallback, size: 64, color: Colors.white24)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Colors.black],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _movieBody() {
    return [
      _actions(onPlay: () => _play(_repo.vodUrl(widget.movie!), _title)),
      FutureBuilder<XtVodInfo>(
        future: _movieInfo,
        builder: (context, snap) {
          final info = snap.data ?? XtVodInfo.empty;
          return _plotAndMeta(info.plot, [info.year, info.genre, info.rating]);
        },
      ),
    ];
  }

  List<Widget> _seriesBody() {
    return [
      FutureBuilder<XtSeriesInfo>(
        future: _seriesInfo,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Column(
              children: [
                _actions(),
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (snap.hasError) {
            return Column(
              children: [
                _actions(),
                ErrorRetry(
                    message: '${snap.error}',
                    onRetry: () => setState(() {})),
              ],
            );
          }
          final info = snap.data ?? XtSeriesInfo.empty;
          final eps = info.episodes;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _actions(
                onPlay: eps.isEmpty
                    ? null
                    : () => _play(_repo.episodeUrl(eps.first), eps.first.title),
              ),
              _plotAndMeta(info.plot, const []),
              if (eps.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nessun episodio'),
                )
              else ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Episodi',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                ...eps.map((e) => ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(e.title),
                      onTap: () => _play(_repo.episodeUrl(e), e.title),
                    )),
              ],
            ],
          );
        },
      ),
    ];
  }

  Widget _plotAndMeta(String plot, List<String> meta) {
    final metaText = meta.where((s) => s.trim().isNotEmpty).join('  ·  ');
    if (plot.isEmpty && metaText.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metaText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(metaText,
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          if (plot.isNotEmpty)
            Text(plot, style: const TextStyle(color: Colors.white70, height: 1.4)),
        ],
      ),
    );
  }
}
