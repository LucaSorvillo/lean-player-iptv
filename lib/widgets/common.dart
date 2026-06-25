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
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Icon(fallback, size: width),
    );
  }
}

/// Riga di un canale live: logo, nome, "ora in onda" (EPG lazy+cache), stella e
/// pulsante info (guida programmi). Tap = riproduci.
class LiveTile extends StatefulWidget {
  final XtLive channel;
  final VoidCallback onPlay;
  const LiveTile({
    super.key,
    required this.channel,
    required this.onPlay,
  });

  @override
  State<LiveTile> createState() => _LiveTileState();
}

class _LiveTileState extends State<LiveTile> {
  late Future<EpgNowNext> _epg;

  @override
  void initState() {
    super.initState();
    _epg = EpgService.instance.nowNext(widget.channel.streamId);
  }

  @override
  void didUpdateWidget(LiveTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.streamId != widget.channel.streamId) {
      _epg = EpgService.instance.nowNext(widget.channel.streamId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: StreamLogo(url: widget.channel.icon, fallback: Icons.live_tv),
      title: Text(widget.channel.name),
      subtitle: FutureBuilder<EpgNowNext>(
        future: _epg,
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
      trailing: FavStar(
        isFav: () =>
            FavoritesStore.instance.isLiveFav(widget.channel.streamId),
        onToggle: () => FavoritesStore.instance.toggleLive(widget.channel),
      ),
      onTap: widget.onPlay,
    );
  }
}
