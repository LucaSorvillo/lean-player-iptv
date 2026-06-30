/// Configurazione di default dell'app IPTV (valori iniziali e preset).
///
/// Server e credenziali non sono più cablati qui: si impostano dall'app e si
/// salvano in `SettingsStore`. Qui restano solo i default/preset.
class ScptvConfig {
  ScptvConfig._();

  /// Nome mostrato dell'app.
  static const String appName = 'IPTV Player';

  /// User-Agent di default (modificabile nelle impostazioni).
  /// `SCPTVPlayer` è quello richiesto dal server SCPTV.
  static const String defaultUserAgent = 'SCPTVPlayer';

  /// Preset rapidi di User-Agent offerti nella schermata impostazioni.
  static const List<String> userAgentPresets = [
    'SCPTVPlayer',
    'VLC/3.0.20 LibVLC/3.0.20',
    'Lavf/60.16.100',
    'okhttp/4.9.3',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  ];
}
