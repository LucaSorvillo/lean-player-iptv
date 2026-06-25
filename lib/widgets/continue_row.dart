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

  void _resume(BuildContext context, ContinueItem e) {
    Widget? screen;
    if (e.type == 'vod') {
      final v = XtVod.fromJson(e.item);
      screen = PlayerScreen(
        url: _repo.vodUrl(v),
        title: e.name,
        resume: e.toRef(),
        initialPosition: Duration(seconds: e.position),
      );
    } else if (e.type == 'series') {
      if (e.episode == null) return;
      final ep = XtEpisode.fromJson(e.episode!);
      screen = PlayerScreen(
        url: _repo.episodeUrl(ep),
        title: ep.title,
        resume: e.toRef(),
        initialPosition: Duration(seconds: e.position),
      );
    } else {
      final c = XtLive.fromJson(e.item);
      screen = PlayerScreen(
        url: _repo.liveUrl(c),
        title: e.name,
        liveStreamId: _repo.supportsEpg ? c.streamId : null,
        resume: e.toRef(),
      );
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
  }
}
