import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'models.dart';
import 'services/catalog_repository.dart';
import 'services/continue_watching_store.dart';
import 'services/settings_store.dart';

/// Riproduzione a schermo intero orizzontale (stile Netflix): landscape +
/// immersivo, controlli che si auto-nascondono, con pulsanti Proporzioni,
/// Impostazioni (tracce) e — per le serie — Episodi ed Episodio successivo.
class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;
  final ContinueRef? resume;
  final Duration initialPosition;

  /// Contesto serie (abilita "Episodi" ed "Episodio successivo").
  final XtSeries? series;
  final List<XtEpisode>? episodes;
  final int episodeIndex;

  const PlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.resume,
    this.initialPosition = Duration.zero,
    this.series,
    this.episodes,
    this.episodeIndex = 0,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final CatalogRepository _repo = CatalogRepository.instance;
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _saveTimer;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _seeked = false;

  late String _currentUrl = widget.url;
  late String _title = widget.title;
  ContinueRef? _resume;
  Duration _resumeFrom = Duration.zero;
  late int _episodeIndex = widget.episodeIndex;

  BoxFit _fit = BoxFit.contain;
  double? _aspectRatio;

  // Modalità proporzioni (ciclo, come l'app Android): nome + fit + aspectRatio.
  static const List<({String label, BoxFit fit, double? ar})> _aspectModes = [
    (label: 'Adatta', fit: BoxFit.contain, ar: null),
    (label: 'Riempi', fit: BoxFit.cover, ar: null),
    (label: 'Stira', fit: BoxFit.fill, ar: null),
    (label: '16:9', fit: BoxFit.contain, ar: 16 / 9),
    (label: '4:3', fit: BoxFit.contain, ar: 4 / 3),
  ];
  int _aspectIndex = 0;
  String _aspectLabel = '';
  bool _aspectLabelVisible = false;
  Timer? _aspectLabelTimer;

  bool get _isSeries =>
      widget.series != null &&
      widget.episodes != null &&
      widget.episodes!.isNotEmpty;

  bool get _wantsResume =>
      _resumeFrom > Duration.zero && _resume?.type != 'live';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _resume = widget.resume;
    _resumeFrom = widget.initialPosition;
    _pos = widget.initialPosition;
    _open();

    _subs.add(_player.stream.position.listen((p) {
      if (_wantsResume && !_seeked) return;
      if (p > Duration.zero) _pos = p;
    }));
    _subs.add(_player.stream.duration.listen((d) {
      _dur = d;
      if (_wantsResume && !_seeked && d > Duration.zero) {
        _seeked = true;
        _player.seek(_resumeFrom);
      }
    }));

    if (_resume != null) {
      _record();
      _saveTimer =
          Timer.periodic(const Duration(seconds: 10), (_) => _record());
    }
  }

  void _open() {
    _player.open(
      Media(_currentUrl,
          httpHeaders: {'User-Agent': SettingsStore.instance.userAgent}),
    );
  }

  void _record() {
    final ref = _resume;
    if (ref == null) return;
    ContinueWatchingStore.instance.record(
      ref,
      position: _pos.inSeconds,
      duration: _dur.inSeconds,
    );
  }

  void _switchEpisode(int i) {
    final eps = widget.episodes;
    final series = widget.series;
    if (eps == null || series == null || i < 0 || i >= eps.length) return;
    final ep = eps[i];
    setState(() {
      _episodeIndex = i;
      _title = ep.title;
      _currentUrl = _repo.episodeUrl(ep);
      _resume = ContinueRef.series(series, ep);
      _resumeFrom = Duration.zero;
      _seeked = true; // episodio scelto: niente seek di ripresa
      _pos = Duration.zero;
      _dur = Duration.zero;
    });
    _open();
    _record();
  }

  void _playNext() {
    if (_isSeries && _episodeIndex + 1 < widget.episodes!.length) {
      _switchEpisode(_episodeIndex + 1);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _aspectLabelTimer?.cancel();
    if (_resume != null) _record();
    _player.dispose();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // --- Menu / overlay ---

  // Cambia ciclicamente le proporzioni e mostra l'etichetta transitoria.
  void _cycleAspect() {
    _aspectIndex = (_aspectIndex + 1) % _aspectModes.length;
    final m = _aspectModes[_aspectIndex];
    setState(() {
      _fit = m.fit;
      _aspectRatio = m.ar;
      _aspectLabel = m.label;
      _aspectLabelVisible = true;
    });
    _aspectLabelTimer?.cancel();
    _aspectLabelTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _aspectLabelVisible = false);
    });
  }

  void _showTracks() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final tracks = _player.state.tracks;
              final cur = _player.state.track;
              Widget section<T>(
                String title,
                List<T> list,
                T current,
                String Function(T) label,
                void Function(T) onPick,
              ) {
                if (list.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(title,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold)),
                    ),
                    ...list.map((t) => ListTile(
                          dense: true,
                          title: Text(label(t),
                              style: const TextStyle(color: Colors.white)),
                          trailing: t == current
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                          onTap: () {
                            onPick(t);
                            setSheet(() {});
                          },
                        )),
                  ],
                );
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    section<AudioTrack>('Audio', tracks.audio, cur.audio,
                        _audioLabel, _player.setAudioTrack),
                    section<SubtitleTrack>('Sottotitoli', tracks.subtitle,
                        cur.subtitle, _subLabel, _player.setSubtitleTrack),
                    section<VideoTrack>('Qualità', tracks.video, cur.video,
                        _vidLabel, _player.setVideoTrack),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showEpisodes() {
    final eps = widget.episodes;
    if (eps == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: eps.length,
          itemBuilder: (ctx, i) {
            final ep = eps[i];
            final current = i == _episodeIndex;
            return ListTile(
              leading: Icon(
                current ? Icons.play_arrow : Icons.play_circle_outline,
                color: current ? Colors.red : Colors.white70,
              ),
              title: Text(ep.title,
                  style:
                      TextStyle(color: current ? Colors.red : Colors.white)),
              onTap: () {
                Navigator.of(ctx).pop();
                _switchEpisode(i);
              },
            );
          },
        ),
      ),
    );
  }

  String _label(String id, String? title, String? language) {
    if (id == 'auto') return 'Auto';
    if (id == 'no') return 'Nessuno';
    final parts = [
      if (title != null && title.isNotEmpty) title,
      if (language != null && language.isNotEmpty) language,
    ];
    return parts.isEmpty ? 'Traccia $id' : parts.join(' · ');
  }

  String _audioLabel(AudioTrack t) => _label(t.id, t.title, t.language);
  String _subLabel(SubtitleTrack t) => _label(t.id, t.title, t.language);
  String _vidLabel(VideoTrack t) {
    if (t.id == 'auto') return 'Auto';
    if (t.id == 'no') return 'Nessuno';
    if (t.w != null && t.h != null) return '${t.w}×${t.h}';
    return _label(t.id, t.title, t.language);
  }

  // Pulsante del footer con icona + etichetta.
  Widget _footerButton(IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  MaterialVideoControlsThemeData _controlsTheme() {
    return MaterialVideoControlsThemeData(
      seekOnDoubleTap: true,
      seekBarMargin: const EdgeInsets.only(left: 16, right: 16, bottom: 72),
      bottomButtonBarMargin:
          const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      topButtonBarMargin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      // In alto resta solo Indietro (+ titolo).
      topButtonBar: [
        MaterialCustomButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            _title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
      // Pulsanti nel footer, distribuiti su tutta la larghezza, con etichetta.
      bottomButtonBar: [
        const MaterialPositionIndicator(),
        const Spacer(),
        _footerButton(Icons.aspect_ratio, 'Proporzioni', _cycleAspect),
        const Spacer(),
        _footerButton(Icons.tune, 'Impostazioni', _showTracks),
        if (_isSeries) ...[
          const Spacer(),
          _footerButton(Icons.video_library, 'Episodi', _showEpisodes),
          const Spacer(),
          _footerButton(Icons.skip_next, 'Successivo', _playNext),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _controlsTheme();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MaterialVideoControlsTheme(
              normal: theme,
              fullscreen: theme,
              child: Video(
                controller: _controller,
                controls: MaterialVideoControls,
                fit: _fit,
                aspectRatio: _aspectRatio,
              ),
            ),
          ),
          // Etichetta transitoria delle proporzioni (appare e svanisce).
          IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _aspectLabelVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xB3000000),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _aspectLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
