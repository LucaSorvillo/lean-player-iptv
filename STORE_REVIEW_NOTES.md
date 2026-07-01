# Note per la review sugli store (LeanPlayerIPTV)

Documento di supporto alla pubblicazione. **Non è incluso nel bundle dell'app.**
Non è consulenza legale.

---

## 1. App Review Notes — testo da incollare in App Store Connect (in inglese)

> **LeanPlayerIPTV is a generic media player ("bring your own playlist").** The app
> does **not** include, host, or provide any content, channel list, or playlist.
> It ships **empty**: on first launch the user must enter their **own** Xtream
> Codes credentials or an **M3U playlist URL** for a service they are legally
> entitled to use. All streams and metadata come exclusively from the server the
> user configures.
>
> **Demo account for review** (please use to test playback):
> - Mode: Xtream Codes
> - Server URL: `__________`
> - Username: `__________`
> - Password: `__________`
> *(or an M3U URL: `__________`)*
>
> **Network (ATS):** the app sets `NSAllowsArbitraryLoads` because it must connect
> to **third-party IPTV servers chosen by the user**, many of which are only
> reachable over HTTP (no HTTPS). The set of hosts is not known in advance, so a
> domain allow-list is not possible.
>
> **Parental controls:** the app includes an optional **PIN lock** (asked at
> launch) and an **"hide adult content"** filter that hides categories/content
> flagged as adult. Age rating is set accordingly (user-supplied, unfiltered
> content → 17+/18+).
>
> **No downloading/recording** of third-party streams is provided.

⚠️ Compila i `__________` con un **account demo reale** prima dell'invio: Apple
rigetta le app con login se non può testarle.

---

## 2. Checklist compliance pre-submission (IT)

- [x] Nessun contenuto/playlist/credenziale precaricati (app vuota al primo avvio).
- [x] Branding neutro e originale (nome **LeanPlayerIPTV**, bundle id
      `com.lucasorvillo.iptvplayer`); nessun marchio/logo di terzi.
- [x] Controllo parentale: **PIN** all'avvio + filtro "contenuti per adulti".
- [x] Disclaimer d'uso legittimo nella schermata di configurazione.
- [x] Nessuna funzione di download/registrazione degli stream.
- [ ] **Account demo** inserito nelle App Review Notes (sopra).
- [ ] **Age rating 17+/18+** dichiarato in App Store Connect (contenuti non filtrati).
- [ ] Icona e screenshot originali, senza loghi/canali di terzi.
- [ ] Se aggiungi funzioni "pro" a pagamento → usa **In-App Purchase** di Apple (3.1.1).

## 3. Rischi residui (da tenere presente)

- L'approvazione è **revocabile**: i detentori dei diritti possono inviare
  segnalazioni DMCA → rimozione anche dopo mesi; la recidiva porta alla
  sospensione dell'account sviluppatore.
- **Contesto Italia**: AGCOM Piracy Shield e le azioni DAZN/Serie A colpiscono
  anche gli utenti finali. Un player neutro non è illegale di per sé, ma evita
  qualsiasi legame commerciale/marketing con servizi di stream non licenziati.

## 4. Requisiti pratici

- **Apple Developer Program**: 99 USD/anno. Review tipica 24-48h.
- **Google Play**: 25 USD una-tantum; policy IPTV più permissiva all'ingresso,
  stesso rischio di takedown su segnalazione.
