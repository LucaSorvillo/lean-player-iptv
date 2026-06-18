/// Configurazione del servizio SCPTV.
class ScptvConfig {
  ScptvConfig._();

  /// User-Agent richiesto dal server per lo streaming (vincolo anti-restream).
  static const String userAgent = 'SCPTVPlayer';

  /// Server reale (Xtream Codes). Ricavabile anche dal bootstrap "getappdns".
  static const String defaultHost = 'android.cdnscp.com';
  static const int defaultPort = 8880;

  /// Credenziali precompilate (modificabili dall'utente in app).
  static const String defaultUsername = 'narvalo117';
  static const String defaultPassword = '24012026';

  // --- Bootstrap "getappdns" (centralino) per ricavare dinamicamente il server ---
  static const String bootstrapUrl = 'https://sbpscp.scpnew.com/api';
  static const String bootstrapKeyA = 'U0riAqGRWbCHLjV'; // F0
  static const String bootstrapKeyS =
      '5QtPk9MhZlnrHGAocXgjmsaJODdFI81xBNLEpy7iTRSWwv0KCe'; // G0
  static const String bootstrapSalt = r'*Njh0&$@HAH828283636JSJSHS*';
}
