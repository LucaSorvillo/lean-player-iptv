import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'models.dart';
import 'services/continue_watching_store.dart';
import 'services/epg_service.dart';
import 'services/settings_store.dart';

/// Schermata di riproduzione: dato un URL (live / film / episodio) riproduce con
/// media_kit (libmpv) forzando lo User-Agent richiesto dal server SCPTV.
///
/// Se [liveStreamId] è valorizzato (canale live), in verticale sotto al player
/// viene mostrata la guida programmi (EPG); in orizzontale solo il video.
class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String? liveStreamId;

  /// Se valorizzato, la riproduzione viene registrata in "Continua a guardare".
  final ContinueRef? resume;

  /// Posizione iniziale da cui riprendere (film/serie).
  final Duration initialPosition;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.liveStreamId,
    this.resume,
    this.initialPosition = Duration.zero,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _saveTimer;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _seeked = false;

  bool get _wantsResume =>
      widget.initialPosition > Duration.zero && widget.resume?.type != 'live';

  @override
  void initState() {
    super.initState();
    _pos = widget.initialPosition;
    _player.open(
      Media(widget.url,
          httpHeaders: {'User-Agent': SettingsStore.instance.userAgent}),
    );

    _subs.add(_player.stream.position.listen((p) {
      // per i contenuti ripresi, ignora finché non è avvenuto il seek
      if (_wantsResume && !_seeked) return;
      if (p > Duration.zero) _pos = p;
    }));
    _subs.add(_player.stream.duration.listen((d) {
      _dur = d;
      if (_wantsResume && !_seeked && d > Duration.zero) {
        _seeked = true;
        _player.seek(widget.initialPosition);
      }
    }));

    if (widget.resume != null) {
      _record(); // compare subito in "Continua a guardare"
      _saveTimer =
          Timer.periodic(const Duration(seconds: 10), (_) => _record());
    }
  }

  void _record() {
    final ref = widget.resume;
    if (ref == null) return;
    ContinueWatchingStore.instance.record(
      ref,
      position: _pos.inSeconds,
      duration: _dur.inSeconds,
    );
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    if (widget.resume != null) _record();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = Video(controller: _controller);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title)),
      body: widget.liveStreamId == null
          ? Center(child: video)
          : OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  return Center(child: video);
                }
                return Column(
                  children: [
                    AspectRatio(aspectRatio: 16 / 9, child: video),
                    Expanded(child: _EpgPanel(streamId: widget.liveStreamId!)),
                  ],
                );
              },
            ),
    );
  }
}

/// Guida programmi mostrata sotto al player per i canali live.
class _EpgPanel extends StatefulWidget {
  final String streamId;
  const _EpgPanel({required this.streamId});

  @override
  State<_EpgPanel> createState() => _EpgPanelState();
}

class _EpgPanelState extends State<_EpgPanel> {
  late final Future<List<XtEpg>> _future =
      EpgService.instance.listing(widget.streamId);

  String _hhmm(DateTime? d) {
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: FutureBuilder<List<XtEpg>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? const <XtEpg>[];
          final now = DateTime.now();
          // mostra il programma corrente e quelli successivi (salta i passati)
          final upcoming = all
              .where((e) => e.end == null || !e.end!.isBefore(now))
              .toList();
          if (upcoming.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Guida programmi non disponibile.'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: upcoming.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'GUIDA PROGRAMMI',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                );
              }
              final e = upcoming[i - 1];
              final isNow = e.isNow;
              return ListTile(
                dense: true,
                leading: SizedBox(
                  width: 44,
                  child: Text(_hhmm(e.start), style: theme.textTheme.bodySmall),
                ),
                title: Text(
                  e.title.isEmpty ? '—' : e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: isNow ? FontWeight.bold : FontWeight.normal),
                ),
                subtitle: (isNow && e.description.isNotEmpty)
                    ? Text(e.description,
                        maxLines: 3, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: isNow
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('ORA',
                            style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
