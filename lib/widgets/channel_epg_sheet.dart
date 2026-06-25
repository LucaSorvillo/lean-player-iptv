import 'package:flutter/material.dart';

import '../models.dart';
import '../services/epg_service.dart';
import '../services/favorites_store.dart';
import 'common.dart';

/// Mostra un bottom sheet con "ora in onda" / "a seguire" del canale, più i
/// pulsanti Guarda e Preferiti.
Future<void> showChannelEpg(
  BuildContext context,
  XtLive channel,
  VoidCallback onPlay,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _ChannelEpgSheet(channel: channel, onPlay: onPlay),
  );
}

String _hhmm(DateTime? d) {
  if (d == null) return '';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ChannelEpgSheet extends StatefulWidget {
  final XtLive channel;
  final VoidCallback onPlay;
  const _ChannelEpgSheet({required this.channel, required this.onPlay});

  @override
  State<_ChannelEpgSheet> createState() => _ChannelEpgSheetState();
}

class _ChannelEpgSheetState extends State<_ChannelEpgSheet> {
  late final Future<EpgNowNext> _epg =
      EpgService.instance.nowNext(widget.channel.streamId);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.channel.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FavStar(
                  isFav: () =>
                      FavoritesStore.instance.isLiveFav(widget.channel.streamId),
                  onToggle: () =>
                      FavoritesStore.instance.toggleLive(widget.channel),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<EpgNowNext>(
              future: _epg,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final data = snap.data;
                if (data == null || data.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Guida programmi non disponibile.'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.now != null) _block(context, 'Ora in onda', data.now!),
                    if (data.next != null) ...[
                      const SizedBox(height: 12),
                      _block(context, 'A seguire', data.next!),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onPlay();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Guarda ora'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _block(BuildContext context, String label, XtEpg e) {
    final range = [_hhmm(e.start), _hhmm(e.end)]
        .where((s) => s.isNotEmpty)
        .join(' - ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 2),
        Text(e.title.isEmpty ? '—' : e.title,
            style: Theme.of(context).textTheme.titleMedium),
        if (range.isNotEmpty)
          Text(range, style: Theme.of(context).textTheme.bodySmall),
        if (e.description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(e.description, maxLines: 4, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}
