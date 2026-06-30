import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/epg_service.dart';
import '../services/favorites_store.dart';

/// Stato d'errore riutilizzabile, con pulsante "Riprova".
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selettore di categoria (default: "Tutte le categorie" = `null`).
class CategoryDropdown extends StatelessWidget {
  final List<XtCategory> categories;
  final String? value;
  final ValueChanged<String?> onChanged;
  const CategoryDropdown({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.category_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButton<String?>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tutte le categorie'),
                ),
                ...categories.map((c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stella preferiti generica: si aggiorna da sola quando cambia lo store.
class FavStar extends StatelessWidget {
  final bool Function() isFav;
  final VoidCallback onToggle;
  const FavStar({super.key, required this.isFav, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FavoritesStore.instance,
      builder: (context, _) {
        final fav = isFav();
        return IconButton(
          icon: Icon(fav ? Icons.star : Icons.star_border,
              color: fav ? Colors.amber : null),
          tooltip: fav ? 'Rimuovi dai preferiti' : 'Aggiungi ai preferiti',
          onPressed: onToggle,
        );
      },
    );
  }
}

/// Logo di un canale/contenuto, con fallback a icona.
class StreamLogo extends StatelessWidget {
  final String url;
  final IconData fallback;
  final double width;
  final double height;
  const StreamLogo({
    super.key,
    required this.url,
    required this.fallback,
    this.width = 48,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return Icon(fallback, size: width);
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(width: width, height: height, color: Colors.white10),
      errorWidget: (_, _, _) => Icon(fallback, size: width),
    );
  }
}

/// Riga di un canale live: logo, nome, "ora in onda" (EPG lazy+cache), stella e
/// pulsante info (guida programmi). Tap = riproduci.
class LiveTile extends StatefulWidget {
  final XtLive channel;
  final VoidCallback onPlay;

  /// Mostra "ora in onda" come sottotitolo (solo se la sorgente ha l'EPG).
  final bool showEpg;

  const LiveTile({
    super.key,
    required this.channel,
    required this.onPlay,
    this.showEpg = true,
  });

  @override
  State<LiveTile> createState() => _LiveTileState();
}

class _LiveTileState extends State<LiveTile> {
  Future<EpgNowNext>? _epg;

  @override
  void initState() {
    super.initState();
    if (widget.showEpg) {
      _epg = EpgService.instance.nowNext(widget.channel.streamId);
    }
  }

  @override
  void didUpdateWidget(LiveTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showEpg &&
        oldWidget.channel.streamId != widget.channel.streamId) {
      _epg = EpgService.instance.nowNext(widget.channel.streamId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final epg = _epg;
    return ListTile(
      leading: StreamLogo(url: widget.channel.icon, fallback: Icons.live_tv),
      title: Text(widget.channel.name),
      subtitle: epg == null
          ? null
          : FutureBuilder<EpgNowNext>(
              future: epg,
              builder: (context, snap) {
                final now = snap.data?.now;
                if (now == null || now.title.isEmpty) {
                  return const SizedBox.shrink();
                }
                final t = now.startHHmm;
                return Text(
                  t.isEmpty ? now.title : '$t · ${now.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showEpg)
            IconButton(
              icon: const Icon(Icons.event_note),
              tooltip: 'Guida programmi',
              onPressed: _showGuide,
            ),
          FavStar(
            isFav: () =>
                FavoritesStore.instance.isLiveFav(widget.channel.streamId),
            onToggle: () => FavoritesStore.instance.toggleLive(widget.channel),
          ),
        ],
      ),
      onTap: widget.onPlay,
    );
  }

  // Guida programmi: palinsesto completo del canale in un bottom sheet.
  void _showGuide() {
    final streamId = widget.channel.streamId;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      builder: (ctx) {
        var future = EpgService.instance.fullListing(streamId);
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheet) => FractionallySizedBox(
              heightFactor: 0.78,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.event_note, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.channel.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<List<XtEpg>>(
                      future: future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return ErrorRetry(
                            message: 'Guida non disponibile.',
                            onRetry: () => setSheet(() => future =
                                EpgService.instance.fullListing(streamId)),
                          );
                        }
                        final list = snap.data ?? const <XtEpg>[];
                        if (list.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                  'Nessuna guida disponibile per questo canale.'),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (ctx, i) => _guideRow(list[i]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Riga di palinsesto: orario, titolo (grassetto/rosso se in onda), descrizione.
  Widget _guideRow(XtEpg e) {
    final now = e.isNow;
    final color = now ? Colors.red : Colors.white;
    return ListTile(
      dense: true,
      leading: Text(
        e.startHHmm,
        style: TextStyle(
          color: now ? Colors.red : Colors.white70,
          fontWeight: now ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      title: Text(
        e.title.isEmpty ? 'Programma' : e.title,
        style: TextStyle(
            color: color, fontWeight: now ? FontWeight.bold : FontWeight.w500),
      ),
      subtitle: e.description.isEmpty
          ? null
          : Text(
              e.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54),
            ),
    );
  }
}
