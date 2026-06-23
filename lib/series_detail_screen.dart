import 'package:flutter/material.dart';

import 'models.dart';
import 'player_screen.dart';
import 'xtream_api.dart';

/// Dettaglio di una serie: elenco episodi (tutte le stagioni) → player.
class SeriesDetailScreen extends StatefulWidget {
  final XtreamApi api;
  final XtSeries series;

  const SeriesDetailScreen({super.key, required this.api, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late final Future<List<XtEpisode>> _future =
      widget.api.seriesInfo(widget.series.seriesId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.series.name)),
      body: FutureBuilder<List<XtEpisode>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Errore: ${snap.error}'));
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
                    url: widget.api.episodeUrl(e.id, e.ext),
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
