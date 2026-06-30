import 'package:flutter/material.dart';

import '../models.dart';
import '../player_screen.dart';
import '../services/catalog_repository.dart';
import '../services/continue_watching_store.dart';
import 'content_row.dart';
import 'poster_card.dart';

/// Riga "Continua a guardare" per un tipo (live/vod/series). Reattiva allo store:
/// compare/scompare e si aggiorna da sola. Tap = riprendi dalla posizione.
class ContinueWatchingRow extends StatelessWidget {
  final String type;
  const ContinueWatchingRow({super.key, required this.type});

  CatalogRepository get _repo => CatalogRepository.instance;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ContinueWatchingStore.instance,
      builder: (context, _) {
        final items = ContinueWatchingStore.instance.ofType(type);
        if (items.isEmpty) return const SizedBox.shrink();
        final fallback = type == 'series'
            ? Icons.video_library
            : (type == 'live' ? Icons.live_tv : Icons.movie);
        return ContentRow(
          title: 'Continua a guardare',
          itemCount: items.length,
          itemBuilder: (context, i) {
            final e = items[i];
            return PosterCard(
              imageUrl: e.poster,
              title: e.name,
              fallback: fallback,
              progress: type == 'live' || e.progress <= 0 ? null : e.progress,
              onTap: () => _resume(context, e),
            );
          },
        );
      },
    );
  }

  Future<void> _resume(BuildContext context, ContinueItem e) async {
    if (e.type == 'vod') {
      final v = XtVod.fromJson(e.item);
      _push(
        context,
        PlayerScreen(
          url: _repo.vodUrl(v),
          title: e.name,
          resume: e.toRef(),
          initialPosition: Duration(seconds: e.position),
        ),
      );
    } else if (e.type == 'series') {
      if (e.episode == null) return;
      final series = XtSeries.fromJson(e.item);
      final ep = XtEpisode.fromJson(e.episode!);
      // recupera la lista episodi (in cache) per abilitare Episodi/Successivo
      List<XtEpisode>? eps;
      var index = 0;
      try {
        final info = await _repo.source.seriesInfo(series.seriesId);
        if (info.episodes.isNotEmpty) {
          eps = info.episodes;
          final found = eps.indexWhere((x) => x.id == ep.id);
          if (found >= 0) index = found;
        }
      } catch (_) {}
      if (!context.mounted) return;
      _push(
        context,
        PlayerScreen(
          url: _repo.episodeUrl(ep),
          title: ep.title,
          resume: e.toRef(),
          initialPosition: Duration(seconds: e.position),
          series: series,
          episodes: eps,
          episodeIndex: index,
        ),
      );
    } else {
      final c = XtLive.fromJson(e.item);
      _push(
        context,
        PlayerScreen(url: _repo.liveUrl(c), title: e.name, resume: e.toRef()),
      );
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
