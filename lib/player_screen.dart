import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'services/continue_watching_store.dart';
import 'services/settings_store.dart';

/// Riproduzione a schermo intero orizzontale (stile Netflix): all'apertura forza
/// landscape + UI immersiva, all'uscita ripristina verticale. Riproduce con
/// media_kit (libmpv) forzando lo User-Agent richiesto dal server.
///
/// Se [resume] è valorizzato, la riproduzione viene registrata in "Continua a
/// guardare" e (per film/serie) ripresa da [initialPosition].
class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final ContinueRef? resume;
  final Duration initialPosition;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
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

    // Schermo intero orizzontale (stile Netflix).
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

    // Ripristina verticale + barre di sistema.
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: SizedBox.expand(child: Video(controller: _controller)),
    );
  }
}
