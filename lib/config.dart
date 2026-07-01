/// Configurazione di default dell'app IPTV (valori iniziali e preset).
///
/// Server e credenziali non sono più cablati qui: si impostano dall'app e si
/// salvano in `SettingsStore`. Qui restano solo i default/preset.
class AppConfig {
  AppConfig._();

  /// Nome mostrato dell'app.
  static const String appName = 'LeanPlayerIPTV';

  /// User-Agent di default (modificabile nelle impostazioni). Alcuni server IPTV
  /// accettano solo un User-Agent specifico: in tal caso impostalo dal campo
  /// User-Agent nelle impostazioni.
  static const String defaultUserAgent = 'LeanPlayerIPTV';

  /// Preset rapidi di User-Agent offerti nella schermata impostazioni.
  static const List<String> userAgentPresets = [
    'LeanPlayerIPTV',
    'VLC/3.0.20 LibVLC/3.0.20',
    'Lavf/60.16.100',
    'okhttp/4.9.3',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
  ];
}
