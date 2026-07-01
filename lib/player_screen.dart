import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'models.dart';
import 'services/catalog_repository.dart';
import 'services/connectivity_service.dart';
import 'services/continue_watching_store.dart';
import 'services/settings_store.dart';

/// Riproduzione a schermo intero orizzontale (stile Netflix): landscape +
/// immersivo, con controlli personalizzati (auto-hide che si resetta a ogni
/// tocco), Proporzioni, Impostazioni (tracce) e — per le serie — Episodi ed
/// Episodio successivo.
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

  // Visibilità controlli (auto-hide che si resetta a ogni interazione).
  bool _controlsVisible = true;
  Timer? _hideTimer;
  double? _dragValue;
  double _doubleTapX = 0;

  // Barre verticali laterali (luminosità sx / volume dx), visibili coi controlli.
  double _brightness = 0.5; // luminosità schermo (0..1)
  double _volume = 0.5; // volume di SISTEMA (0..1)
  double? _initialVolume; // volume di sistema all'apertura, per ripristinarlo

  bool get _isSeries =>
      widget.series != null &&
      widget.episodes != null &&
      widget.episodes!.isNotEmpty;

  bool get _isLive => widget.resume?.type == 'live';

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
    _initLevels();

    _resume = widget.resume;
    _resumeFrom = widget.initialPosition;
    _pos = widget.initialPosition;
    _open();
    _resetHideTimer();

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

  // --- Visibilità controlli ---
  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _resetHideTimer();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _handleDoubleTap() {
    if (_isLive) {
      _showControls();
      return;
    }
    final width = MediaQuery.of(context).size.width;
    final pos = _player.state.position;
    final target = _doubleTapX < width / 2
        ? pos - const Duration(seconds: 10)
        : pos + const Duration(seconds: 10);
    _player.seek(target < Duration.zero ? Duration.zero : target);
    _showControls();
  }

  // --- Livelli (luminosità schermo + volume di sistema) per le barre laterali ---
  Future<void> _initLevels() async {
    try {
      _brightness = await ScreenBrightness().application;
    } catch (_) {
      // luminosità non leggibile: resta il default
    }
    try {
      // Nascondi l'HUD di sistema: usiamo la barra custom.
      await FlutterVolumeController.updateShowSystemUI(false);
      final v = await FlutterVolumeController.getVolume();
      if (v != null) _volume = v;
      _initialVolume = _volume; // memorizzato per ripristinarlo all'uscita
      // Tiene la barra in sync coi tasti fisici / Control Center.
      FlutterVolumeController.addListener(
        (vol) {
          if (mounted) setState(() => _volume = vol);
        },
        emitOnStart: false,
      );
    } catch (_) {
      // volume di sistema non disponibile (es. simulatore): resta il default
    }
    if (mounted) setState(() {});
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
    _showControls();
  }

  void _playNext() {
    if (_isSeries && _episodeIndex + 1 < widget.episodes!.length) {
      _switchEpisode(_episodeIndex + 1);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _hideTimer?.cancel();
    _aspectLabelTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    if (_resume != null) _record();
    _player.dispose();
    FlutterVolumeController.removeListener();
    // Ripristina il volume di sistema com'era prima di aprire il player.
    if (_initialVolume != null) FlutterVolumeController.setVolume(_initialVolume!);
    FlutterVolumeController.updateShowSystemUI(true);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ScreenBrightness().resetApplicationScreenBrightness();
    super.dispose();
  }

  // --- Proporzioni: ciclo + etichetta transitoria ---
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

  // --- Tracce (audio / sottotitoli / qualità) ---
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
    if (eps == null || eps.isEmpty) return;
    final seasons = (<int>{for (final e in eps) e.season}.toList())..sort();
    final curIdx =
        (_episodeIndex >= 0 && _episodeIndex < eps.length) ? _episodeIndex : 0;
    var sheetSeason = eps[curIdx].season; // parte dalla stagione in corso
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (seasons.length > 1)
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final s in seasons)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: ChoiceChip(
                            label: Text(seasonLabel(s)),
                            selected: s == sheetSeason,
                            onSelected: (_) => setSheet(() => sheetSeason = s),
                          ),
                        ),
                    ],
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var i = 0; i < eps.length; i++)
                      if (eps[i].season == sheetSeason)
                        _episodeSheetTile(ctx, eps, i),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Voce episodio nell'overlay: copertina + titolo (rosso se in corso).
  Widget _episodeSheetTile(BuildContext ctx, List<XtEpisode> eps, int i) {
    final e = eps[i];
    final current = i == _episodeIndex;
    final img = e.image.isNotEmpty ? e.image : (widget.series?.cover ?? '');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 92,
          height: 52,
          child: img.isEmpty
              ? Container(
                  color: Colors.white10,
                  child: Icon(
                      current ? Icons.play_arrow : Icons.play_circle_outline,
                      color: current ? Colors.red : Colors.white70))
              : CachedNetworkImage(
                  imageUrl: img,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: Colors.white10),
                  errorWidget: (_, _, _) => Container(color: Colors.white10),
                ),
        ),
      ),
      title: Text(e.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: current ? Colors.red : Colors.white)),
      subtitle: e.episodeNum > 0
          ? Text('Ep. ${e.episodeNum}',
              style: const TextStyle(color: Colors.white54))
          : null,
      onTap: () {
        Navigator.of(ctx).pop();
        _switchEpisode(i);
      },
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

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // --- UI controlli ---
  Widget _footerButton(IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: () {
        onPressed();
        _resetHideTimer();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

  Widget _centerControls() {
    return StreamBuilder<bool>(
      stream: _player.stream.buffering,
      initialData: false,
      builder: (_, buf) {
        if (buf.data ?? false) {
          return const CircularProgressIndicator(color: Colors.white);
        }
        return StreamBuilder<bool>(
          stream: _player.stream.playing,
          initialData: _player.state.playing,
          builder: (_, snap) {
            final playing = snap.data ?? false;
            return IconButton(
              iconSize: 64,
              color: Colors.white,
              icon: Icon(playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill),
              onPressed: () {
                _player.playOrPause();
                _resetHideTimer();
              },
            );
          },
        );
      },
    );
  }

  Widget _seekRow() {
    if (_isLive) {
      return const Row(
        children: [
          Icon(Icons.circle, color: Colors.red, size: 10),
          SizedBox(width: 6),
          Text('IN DIRETTA',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      );
    }
    const style = TextStyle(color: Colors.white, fontSize: 12);
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      initialData: _player.state.position,
      builder: (_, snap) {
        final dur = _player.state.duration;
        final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final posMs = (snap.data ?? Duration.zero).inMilliseconds.toDouble();
        final value = (_dragValue ?? posMs).clamp(0.0, maxMs).toDouble();
        return Row(
          children: [
            Text(_fmtDur(Duration(milliseconds: value.toInt())), style: style),
            Expanded(
              child: Slider(
                value: value,
                max: maxMs,
                activeColor: Colors.red,
                inactiveColor: Colors.white24,
                onChangeStart: (_) => _hideTimer?.cancel(),
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  _player.seek(Duration(milliseconds: v.toInt()));
                  setState(() => _dragValue = null);
                  _resetHideTimer();
                },
              ),
            ),
            Text(_fmtDur(dur), style: style),
          ],
        );
      },
    );
  }

  Widget _buttonsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _footerButton(Icons.aspect_ratio, 'Proporzioni', _cycleAspect),
        _footerButton(Icons.tune, 'Impostazioni', _showTracks),
        if (_isSeries)
          _footerButton(Icons.video_library, 'Episodi', _showEpisodes),
        if (_isSeries)
          _footerButton(Icons.skip_next, 'Successivo', _playNext),
      ],
    );
  }

  // Barra di livello verticale (slider ruotato) con icona sotto.
  Widget _levelBar({
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 130,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.white,
                inactiveTrackColor: const Color(0xFF6C6B6B),
                thumbColor: Colors.white,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: onChanged,
                onChangeStart: (_) => _hideTimer?.cancel(),
                onChangeEnd: (_) => _resetHideTimer(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Icon(icon, color: Colors.white, size: 24),
      ],
    );
  }

  IconData _brightnessIcon(double v) => v < 0.34
      ? Icons.brightness_low
      : (v < 0.67 ? Icons.brightness_medium : Icons.brightness_high);

  IconData _volumeIcon(double v) => v <= 0.01
      ? Icons.volume_off
      : (v < 0.5 ? Icons.volume_down : Icons.volume_up);

  Widget _controlsOverlay() {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xCC000000),
                ],
                stops: [0.0, 0.25, 0.6, 1.0],
              ),
            ),
          ),
        ),
        // Barre verticali: luminosità (sx) e volume di sistema (dx), in alto e
        // verso il centro, dentro la safe area (sempre toccabili su iPhone).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(
                top: 52,
                left: MediaQuery.of(context).size.width * 0.18,
                right: MediaQuery.of(context).size.width * 0.18,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _levelBar(
                    icon: _brightnessIcon(_brightness),
                    value: _brightness,
                    onChanged: (v) {
                      setState(() => _brightness = v);
                      ScreenBrightness().setApplicationScreenBrightness(v);
                    },
                  ),
                  _levelBar(
                    icon: _volumeIcon(_volume),
                    value: _volume,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      FlutterVolumeController.setVolume(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        // Barra superiore: Indietro + titolo.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Play/Pausa al centro.
        Center(child: _centerControls()),
        // Barra inferiore: tempi + seek bar, poi i pulsanti azione.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _seekRow(),
                  _buttonsRow(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Video(
              controller: _controller,
              controls: NoVideoControls,
              fit: _fit,
              aspectRatio: _aspectRatio,
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTapDown: (d) => _doubleTapX = d.localPosition.dx,
              onDoubleTap: _handleDoubleTap,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _controlsOverlay(),
                ),
              ),
            ),
          ),
          // Etichetta transitoria delle proporzioni.
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
          // Banner "Sei offline": sempre visibile (fuori dall'auto-hide dei controlli).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: ListenableBuilder(
                listenable: ConnectivityService.instance,
                builder: (context, _) {
                  if (ConnectivityService.instance.isOnline) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB00020),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off,
                                size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Sei offline',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
