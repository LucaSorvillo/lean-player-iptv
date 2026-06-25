import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'services/catalog_repository.dart';
import 'services/favorites_store.dart';
import 'widgets/common.dart';

/// Dettaglio di una serie: elenco episodi (tutte le stagioni) → player.
class SeriesDetailScreen extends StatefulWidget {
  final XtSeries series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final CatalogRepository _repo = CatalogRepository.instance;
  late Future<List<XtEpisode>> _future =
      _repo.source.seriesInfo(widget.series.seriesId);

  void _retry() =>
      setState(() => _future = _repo.source.seriesInfo(widget.series.seriesId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.series.name),
        actions: [
          FavStar(
            isFav: () =>
                FavoritesStore.instance.isSeriesFav(widget.series.seriesId),
            onToggle: () =>
                FavoritesStore.instance.toggleSeries(widget.series),
          ),
        ],
      ),
      body: FutureBuilder<List<XtEpisode>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorRetry(message: '${snap.error}', onRetry: _retry);
          }
          final list = snap.data ?? const [];
          if (list.isEmpty) {
            return const Center(child: Text('Nessun episodio'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final e = list[i];
              return ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: Text(e.title),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PlayerScreen(
                    url: _repo.episodeUrl(e),
                    title: e.title,
                  ),
                )),
              );
            },
          );
        },
      ),
    );
  }
}
